import QtQml

QtObject {
    id: root
    property string label: ""
    property string defaultLabel: ""
    readonly property string title: label || defaultLabel
    property real now: 0
    property real startedAt: 0
    property real accumulatedMs: 0
    property bool running: true
    property bool finished: false
    readonly property real elapsedMs: accumulatedMs + (running ? Math.max(0, now - startedAt) : 0)
    property real valueMs: elapsedMs
    property int urgency: 0

    function refresh() {}

    function snapshot() {
        return {label: label, startedAt: startedAt, accumulatedMs: accumulatedMs,
            running: running, finished: finished}
    }

    function pause() {
        refresh()
        if (!running) return
        const elapsed = elapsedMs
        running = false
        accumulatedMs = elapsed
    }

    function resume() {
        if (running || finished) return
        startedAt = now
        running = true
    }

    function reset() {
        running = false
        accumulatedMs = 0
        startedAt = now
        finished = false
    }

    function start() {
        if (finished) reset()
        resume()
    }
}
