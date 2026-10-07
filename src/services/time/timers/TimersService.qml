pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import "../../../config"
import "../../"

Singleton {
    id: root
    property real now: Date.now()
    property var countdowns: []
    property var timers: []
    readonly property var entries: countdowns.concat(timers)
    readonly property var activeCountdowns: countdowns.filter(entry => entry.running)
    readonly property var activeTimers: timers.filter(entry => entry.running)
    readonly property var barEntry: activeCountdowns.reduce((nearest, entry) =>
        !nearest || entry.valueMs < nearest.valueMs ? entry : nearest, null) ?? activeTimers[0] ?? null
    signal countdownExpired()

    function validDuration(seconds) {
        return Number.isFinite(seconds) && seconds > 0 && seconds <= Number.MAX_SAFE_INTEGER / 1000
    }

    function addCountdown(seconds, label = "") {
        if (!validDuration(seconds)) return null
        update()
        const entry = countdownComponent.createObject(root, {durationMs: seconds * 1000, startedAt: now, label: label.trim()})
        countdowns = countdowns.concat(entry)
        save()
        return entry
    }

    function addTimer(label = "") {
        update()
        const entry = timerComponent.createObject(root, {startedAt: now, label: label.trim()})
        timers = timers.concat(entry)
        save()
        return entry
    }

    function togglePause(entry) {
        if (!entries.includes(entry)) return
        const wasRunning = entry.running
        update()
        if (wasRunning) entry.pause()
        else entry.start()
        save()
    }

    function reset(entry) {
        if (!entries.includes(entry)) return
        entry.reset()
        save()
    }

    function remove(entry) {
        if (!entries.includes(entry)) return
        countdowns = countdowns.filter(item => item !== entry)
        timers = timers.filter(item => item !== entry)
        save()
        entry.destroy()
    }

    function save() {
        PreferencesRepository.setValue("timers.state", {
            countdowns: countdowns.map(entry => Object.assign(entry.snapshot(), {durationMs: entry.durationMs})),
            timers: timers.map(entry => entry.snapshot())
        })
    }

    function validSnapshot(state) {
        return state && typeof state.label === "string"
            && Number.isFinite(state.startedAt) && state.startedAt >= 0
            && Number.isFinite(state.accumulatedMs) && state.accumulatedMs >= 0
            && typeof state.running === "boolean" && typeof state.finished === "boolean"
            && !(state.running && state.finished)
    }

    function snapshotProperties(state) {
        return {label: state.label, startedAt: state.startedAt, accumulatedMs: state.accumulatedMs,
            running: state.running, finished: state.finished}
    }

    function restore() {
        const saved = PreferencesRepository.value("timers.state", {})
        const savedCountdowns = Array.isArray(saved?.countdowns) ? saved.countdowns : []
        const savedTimers = Array.isArray(saved?.timers) ? saved.timers : []
        countdowns = savedCountdowns.filter(state => validSnapshot(state)
            && Number.isFinite(state.durationMs) && state.durationMs > 0
            && state.durationMs <= Number.MAX_SAFE_INTEGER && state.accumulatedMs <= state.durationMs
            && (!state.finished || state.accumulatedMs === state.durationMs))
            .map(state => countdownComponent.createObject(root,
                Object.assign(snapshotProperties(state), {durationMs: state.durationMs})))
        timers = savedTimers.filter(state => validSnapshot(state) && !state.finished)
            .map(state => timerComponent.createObject(root, snapshotProperties(state)))
        // Reset completed entries saved before countdowns reset automatically.
        const completed = countdowns.filter(entry => entry.finished)
        for (const entry of completed) entry.reset()
        update()
        if (completed.length > 0) save()
    }

    function update(timestamp = Date.now()) {
        now = timestamp
        for (const entry of countdowns) entry.refresh()
    }

    function formatTime(milliseconds, roundUp = false) {
        const total = Math.max(0, roundUp ? Math.ceil(milliseconds / 1000) : Math.floor(milliseconds / 1000))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor(total / 60) % 60
        const seconds = total % 60
        const shortTime = String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
        return hours > 0 ? String(hours).padStart(2, "0") + ":" + shortTime : shortTime
    }

    Component {
        id: countdownComponent
        CountdownEntry {
            now: root.now
            onExpired: {
                root.save()
                root.countdownExpired()
                Quickshell.execDetached(Config.countdownSoundCommand)
            }
        }
    }
    Component { id: timerComponent; StopwatchEntry { now: root.now } }

    Timer {
        interval: Config.timerTickInterval
        running: root.activeCountdowns.length + root.activeTimers.length > 0
        repeat: true
        onTriggered: root.update()
    }

    Component.onCompleted: restore()
}
