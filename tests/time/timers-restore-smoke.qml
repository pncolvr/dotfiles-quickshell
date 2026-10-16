import QtQml
import Quickshell
import "../../src/services"

Scope {
    id: root
    readonly property string phase: Quickshell.env("TIMERS_TEST_PHASE")
    property bool failed: false

    function check(condition, message) {
        if (condition) return
        failed = true
        console.error("TIMERS FAIL: " + message)
    }
    function seed() {
        check(TimersService.entries.length === 0, "empty state remains empty after restart")
        TimersService.addCountdown(600, "Running countdown")
        const countdown = TimersService.addCountdown(90, "Paused countdown")
        TimersService.togglePause(countdown)
        countdown.accumulatedMs = 1234
        const reusable = TimersService.addCountdown(240, "Reusable countdown")
        TimersService.togglePause(reusable)
        reusable.accumulatedMs = 120000
        const timer = TimersService.addTimer("Running timer")
        timer.startedAt -= 10000
        const pausedTimer = TimersService.addTimer("Paused timer")
        TimersService.togglePause(pausedTimer)
        pausedTimer.accumulatedMs = 4567
        const completed = TimersService.addCountdown(240, "Previously finished")
        completed.running = false
        completed.accumulatedMs = completed.durationMs
        completed.finished = true
        const expired = TimersService.addCountdown(1, "Expired while closed")
        // Save before the next tick, simulating shutdown before its deadline.
        expired.startedAt -= 3000
        check(TimersService.save(), "timer snapshot is written successfully")
    }
    function verify() {
        const initialRestore = phase === "restore" || phase === "late"
        check(TimersService.countdowns.length === (initialRestore ? 5 : 4) && TimersService.timers.length === 2,
            "saved entries restore, deleted entries stay deleted")
        const countdown = TimersService.countdowns.find(entry => entry.label === "Paused countdown")
        const expired = TimersService.countdowns.find(entry => entry.label === "Expired while closed")
        const pausedTimer = TimersService.timers.find(entry => entry.label === "Paused timer")
        const timer = TimersService.timers.find(entry => entry.label === "Running timer")
        const reusable = TimersService.countdowns.find(entry => entry.label === "Reusable countdown")
        const completed = TimersService.countdowns.find(entry => entry.label === "Previously finished")
        check(countdown && !countdown.running && countdown.valueMs === 88766, "paused countdown retains exact time")
        check(pausedTimer && !pausedTimer.running && pausedTimer.valueMs === (initialRestore ? 4567 : 0),
            "paused or reset timer retains exact time")
        check(reusable && !reusable.running && reusable.durationMs === 240000
            && reusable.valueMs === (initialRestore ? 120000 : 240000),
            "reset countdown persists its original duration and ready state")
        check(timer?.running && timer.valueMs >= 10000, "elapsed timer includes time across restart")
        check(expired && !expired.finished && !expired.running && expired.valueMs === 1000,
            "overdue countdown resets at startup and retains its original duration")
        check(completed && !completed.finished && !completed.running && completed.valueMs === 240000,
            "previously finished countdown restores reset and silent")
        if (phase === "late") return
        if (phase === "restore") {
            const active = TimersService.countdowns.find(entry => entry.label === "Running countdown")
            check(active?.running && active.valueMs > 590000 && active.valueMs <= 600000
                && TimersService.barEntry === active, "running countdown resumes from saved deadline")
            TimersService.remove(active)
            check(TimersService.barEntry === timer, "deleting restored countdown promotes restored timer")
            TimersService.reset(reusable)
            TimersService.reset(pausedTimer)
        } else {
            check(TimersService.barEntry === timer, "bar ignores restored paused and finished entries")
            for (const entry of TimersService.entries.slice()) TimersService.remove(entry)
            const saved = PreferencesRepository.value("timers.state", {})
            check(saved.countdowns?.length === 0 && saved.timers?.length === 0, "all deletions are persisted")
        }
    }
    Component.onCompleted: {
        if (phase === "late") return
        check(!TimersService.ready, "restore waits for asynchronous database preparation")
        check(TimersService.addTimer("Too early") === null
            && TimersService.addCountdown(60,"Too early") === null && !TimersService.save(),
            "startup cannot create unsaved entries or replace a stored snapshot")
    }
    Timer {
        interval: root.phase === "seed" ? 20 : 350
        running: true
        repeat: true
        onTriggered: {
            if (!PreferencesRepository.ready) return
            if (root.phase === "late")
                root.check(TimersService.ready, "service created after preference loading restores immediately")
            if (!TimersService.ready) return
            const entries = TimersService.entries.slice()
            TimersService.restore()
            root.check(TimersService.entries.length === entries.length
                && TimersService.entries.every((entry,index) => entry === entries[index]), "restoration runs once")
            switch (root.phase) {
            case "seed": root.seed(); break
            case "empty": root.check(TimersService.entries.length === 0, "deletions survive another restart"); break
            default: root.verify(); break
            }
            if (!root.failed) console.log("PASS: timer persistence " + root.phase)
            Qt.quit()
        }
    }
}
