import "../../../config"

TimeEntry {
    id: root
    property real durationMs: 0
    defaultLabel: "Countdown"
    valueMs: Math.max(0, durationMs - elapsedMs)
    urgency: !running ? 0 : valueMs <= Config.countdownUrgentThreshold ? 2
        : valueMs <= Config.countdownWarningThreshold ? 1 : 0
    signal expired()

    function refresh() {
        if (!running || elapsedMs < durationMs) return
        reset()
        expired()
    }
}
