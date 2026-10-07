pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/bar"
import "../../src/modules/system"
import "../../src/services"
import "../../src/services/time/timers"
import "../../src/theme"

Scope {
    id: root
    property bool failed: false
    property int step: 0
    property int alarms: 0
    property int entryAlarms: 0
    property var panel: null
    property var liveCountdown: null
    property var liveTimer: null
    property real pausedValue: 0

    function check(condition, message) {
        if (condition) return
        failed = true
        console.error("TIMERS FAIL: " + message)
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    function selectTab(index) {
        const tabs = find(panel, "timersTabs") as QC.TabBar
        events.mouseClick(tabs.itemAt(index))
        panel.activeTab.forceLayout()
        panel.forceLayout()
    }
    function row(name, index = 0) {
        selectTab(name === "countdownRows" ? 0 : 1)
        const rows = find(panel.activeTab, name) as Repeater
        const column = rows.parent as Column
        column.forceLayout()
        return rows.itemAt(index)
    }
    function click(item) { events.mouseClick(item) }
    function clearEntries() {
        for (const entry of TimersService.entries.slice()) TimersService.remove(entry)
    }
    function checkState() {
        countdown.now += 1250
        check(countdown.valueMs === 128750, "countdowns use elapsed wall time")
        countdown.pause()
        countdown.now += 30000
        check(countdown.valueMs === 128750 && !countdown.running, "paused countdown retains fractional seconds")
        countdown.resume()
        countdown.now += 98750
        check(countdown.valueMs === 30000 && countdown.urgency === 1, "warning threshold")
        countdown.now += 20000
        check(countdown.valueMs === 10000 && countdown.urgency === 2, "urgent threshold")
        countdown.now += 15000
        countdown.refresh()
        countdown.refresh()
        check(!countdown.finished && !countdown.running && countdown.valueMs === 130000
            && countdown.urgency === 0 && entryAlarms === 1,
            "overshooting zero sounds once and automatically resets ready to start")
        countdown.reset()
        check(!countdown.finished && !countdown.running && countdown.valueMs === 130000 && entryAlarms === 1,
            "reset completed countdown restores its duration without an alarm")
        countdown.start()
        countdown.now += 130000
        countdown.refresh()
        check(!countdown.running && countdown.valueMs === 130000 && entryAlarms === 2,
            "reused countdown completes and automatically resets again")

        stopwatch.now += 3125
        stopwatch.pause()
        stopwatch.now += 30000
        check(stopwatch.valueMs === 3125, "elapsed timer pause")
        stopwatch.resume()
        stopwatch.now += 1000
        check(stopwatch.valueMs === 4125, "elapsed timer resume excludes paused time")
        stopwatch.reset()
        stopwatch.now += 1000
        check(!stopwatch.running && stopwatch.valueMs === 0, "reset elapsed timer stops at zero")
        check(TimersService.formatTime(999, true) === "00:01"
            && TimersService.formatTime(999) === "00:00"
            && TimersService.formatTime(3600000) === "01:00:00"
            && TimersService.formatTime(100 * 3600000) === "100:00:00", "duration formatting")

        check(TimersService.addCountdown(0) === null && TimersService.addCountdown(-1) === null
            && TimersService.addCountdown(NaN) === null && TimersService.addCountdown(Infinity) === null,
            "invalid durations do not create entries")
        const first = TimersService.addTimer("First")
        const second = TimersService.addTimer("Second")
        check(TimersService.barEntry === first, "first running timer is the fallback")
        const long = TimersService.addCountdown(120, "Long")
        const short = TimersService.addCountdown(30, "Short")
        check(TimersService.barEntry === short, "shortest running countdown wins")
        TimersService.togglePause(short)
        check(TimersService.barEntry === long, "paused countdown is excluded")
        TimersService.togglePause(long)
        check(TimersService.barEntry === first, "timers shown when all countdowns are paused")
        TimersService.togglePause(first)
        check(TimersService.barEntry === second, "paused timers are excluded")
        TimersService.togglePause(second)
        check(TimersService.barEntry === null, "all paused entries produce icon only")
        TimersService.togglePause(short)
        TimersService.togglePause(long)
        TimersService.update(Math.max(short.startedAt + short.durationMs, long.startedAt + long.durationMs) + 1000)
        check(alarms === 2 && TimersService.barEntry === null && !short.running && !long.running
            && short.valueMs === short.durationMs && long.valueMs === long.durationMs,
            "simultaneous expiration resets both entries and clears the bar")
        check(PreferencesRepository.value("timers.state", {}).countdowns.every(state =>
            !state.running && !state.finished && state.accumulatedMs === 0), "automatic resets are saved on completion")
        TimersService.update(TimersService.now + 1000)
        check(alarms === 2, "completed countdowns do not sound twice")
        clearEntries()
    }

    CountdownEntry {
        id: countdown
        durationMs: 130000
        startedAt: 100000
        now: 100000
        onExpired: {
            root.entryAlarms++
            root.check(!running && !finished && valueMs === durationMs, "expiration signal observes reset state")
        }
    }
    StopwatchEntry { id: stopwatch; startedAt: 100000; now: 100000 }
    Connections { target: TimersService; function onCountdownExpired() { root.alarms++ } }
    Component { id: center; CenterModules { window: testWindow } }
    Test.TestCase { id: events; name: "Timers interaction"; when: false }
    FloatingWindow {
        id: testWindow
        visible: true
        implicitWidth: 560
        implicitHeight: 800
        Item {
            id: canvas
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: Theme.background }
            Item {
                width: parent.width
                height: Theme.barHeight
                Timers { id: trigger; window: testWindow }
            }
            Component.onCompleted: {
                root.panel = trigger.tooltip.createObject(canvas, {x: 30, y: 50})
                root.check(root.panel !== null && center.status === Component.Ready, "public module and center bar imports")
            }
        }
    }

    Timer {
        interval: 350
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                root.checkState()
                root.check(trigger.cursorShape === Qt.PointingHandCursor, "bar has pointing hand cursor")
                root.check(!root.find(trigger, "timersBarText").visible, "empty bar shows just icon")
                root.find(root.panel, "countdownName").text = "Tea"
                root.find(root.panel, "countdownHours").text = "1"
                root.find(root.panel, "countdownMinutes").text = "2"
                root.find(root.panel, "countdownSeconds").text = "3"
                root.click(root.find(root.panel, "countdownStart"))
                root.check(TimersService.countdowns.length === 1 && TimersService.countdowns[0].durationMs === 3723000,
                    "hours, minutes and seconds start a countdown")
                root.liveCountdown = TimersService.countdowns[0]
                root.check(root.find(root.panel, "countdownStart").foreground === Theme.accent,
                    "countdown add icon uses accent")
                root.selectTab(1)
                root.check(root.panel.timersTab.visible && !root.panel.countdownTab.visible,
                    "tabs show only their own entries and creation controls")
                root.click(root.find(root.panel, "timerStart"))
                root.check(root.find(root.panel, "timerStart").foreground === Theme.accent, "timer add icon uses accent")
                root.liveTimer = TimersService.timers[0]
                break
            case 1:
                root.check(root.find(trigger, "timersBarText").text === "01:02:03", "bar displays countdown")
                root.check(root.row("countdownRows").width === root.panel.width, "rows use full panel width")
                root.click(root.find(root.row("countdownRows"), "timerPause"))
                root.pausedValue = root.liveCountdown.valueMs
                root.check(!root.liveCountdown.running && TimersService.barEntry === root.liveTimer, "pause button updates bar")
                break
            case 2:
                root.check(root.liveCountdown.valueMs === root.pausedValue, "UI pause remains stable across ticks")
                root.click(root.find(root.row("countdownRows"), "timerPause"))
                root.check(root.liveCountdown.running && TimersService.barEntry === root.liveCountdown, "resume button")
                root.click(root.find(root.row("countdownRows"), "timerReset"))
                root.check(!root.liveCountdown.running && root.liveCountdown.valueMs === 3723000
                    && root.liveCountdown.label === "Tea" && TimersService.barEntry === root.liveTimer,
                    "reset running countdown preserves name and duration and updates bar")
                root.check(root.find(root.row("countdownRows"), "timerDelete").fillColor === Theme.urgent
                    && root.find(root.row("countdownRows"), "timerDelete").glyph === Theme.deleteIcon, "shared red delete style")
                root.click(root.find(root.row("countdownRows"), "timerDelete"))
                root.check(TimersService.countdowns.length === 0 && TimersService.barEntry === root.liveTimer, "delete removes countdown")
                root.click(root.find(root.row("stopwatchRows"), "timerPause"))
                root.check(!root.liveTimer.running && TimersService.barEntry === null, "timer pause and icon fallback")
                root.click(root.find(root.row("stopwatchRows"), "timerPause"))
                root.click(root.find(root.row("stopwatchRows"), "timerDelete"))
                root.check(TimersService.entries.length === 0, "timer delete")
                root.find(root.panel, "countdownHours").text = "0"
                root.find(root.panel, "countdownMinutes").text = "0"
                root.find(root.panel, "countdownSeconds").text = "0"
                root.check(!root.find(root.panel, "countdownStart").enabled, "zero duration disables start")
                root.liveTimer = TimersService.addTimer()
                root.liveCountdown = TimersService.addCountdown(0.2)
                root.check(root.find(trigger, "timersBarText").color === Theme.urgent, "urgent countdown color on bar")
                break
            case 3:
                if (root.liveCountdown.running) { root.step--; return }
                root.check(!root.liveCountdown.finished && root.liveCountdown.valueMs === 200
                    && root.alarms === 3 && TimersService.barEntry === root.liveTimer,
                    "real clock automatically resets countdown and promotes timer")
                root.check(root.find(root.row("countdownRows"), "timerTime").color === Theme.text,
                    "automatic reset clears countdown warning color")
                root.check(root.find(root.row("countdownRows"), "timerTitle").color === Theme.inactive
                    && root.find(root.row("countdownRows"), "timerPause").glyph === Theme.playIcon
                    && root.find(root.row("countdownRows"), "timerPause").foreground === Theme.ok
                    && root.find(root.row("countdownRows"), "timerPause").fillColor === Theme.alternateBackground,
                    "completed countdown offers green play to start again")
                root.click(root.find(root.row("countdownRows"), "timerPause"))
                root.check(root.liveCountdown.running && !root.liveCountdown.finished
                    && TimersService.countdowns.length === 1 && TimersService.barEntry === root.liveCountdown,
                    "finished countdown starts again in place")
                break
            case 4:
                if (root.liveCountdown.running) { root.step--; return }
                root.check(!root.liveCountdown.finished && root.liveCountdown.valueMs === 200 && root.alarms === 4,
                    "restarted countdown sounds once and automatically resets again")
                root.click(root.find(root.row("countdownRows"), "timerReset"))
                root.check(!root.liveCountdown.finished && !root.liveCountdown.running && root.liveCountdown.valueMs === 200,
                    "reset completed countdown readies its original duration")
                root.click(root.find(root.row("stopwatchRows"), "timerReset"))
                root.check(!root.liveTimer.running && root.liveTimer.valueMs === 0 && TimersService.barEntry === null,
                    "reset running elapsed timer stops at zero and restores icon")
                root.clearEntries()
                root.liveCountdown = TimersService.addCountdown(25)
                root.check(root.find(trigger, "timersBarText").color === Theme.warning, "warning countdown color on bar")
                for (let index = 0; index < 20; index++) TimersService.addTimer("Timer " + index)
                break
            case 5: {
                root.check(root.find(root.row("countdownRows"), "timerTitle").color === Theme.warning
                    && root.find(root.row("countdownRows"), "timerTime").color === Theme.warning,
                    "warning applies to countdown title and time")
                root.selectTab(1)
                const list = root.find(root.panel.activeTab, "timerList") as Flickable
                root.check(list.height <= root.panel.maxListHeight && list.contentHeight > list.height, "long lists scroll within monitor")
                root.check(root.row("stopwatchRows", 19).width === root.panel.width, "overlay scrollbar leaves row width intact")
                const before = TimersService.entries.length
                root.panel.destroy()
                root.panel = trigger.tooltip.createObject(canvas, {x: 30, y: 50})
                root.selectTab(1)
                root.check(TimersService.entries.length === before, "closing panel retains timers")
                const screenshot = Quickshell.env("TIMERS_TEST_SCREENSHOT")
                if (screenshot) canvas.grabToImage(result => result.saveToFile(screenshot))
                break
            }
            default:
                root.check(root.alarms === 4, "pause, reset, deletion and panel lifetime never trigger alarms")
                root.clearEntries()
                root.check(!root.find(trigger, "timersBarText").visible, "deleting everything restores icon")
                if (!root.failed) console.log("PASS: countdowns, elapsed timers, bar priority and panel controls")
                Qt.quit()
            }
        }
    }
}
