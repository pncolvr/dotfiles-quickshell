pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"
import "CaptureCloseTiming.mjs" as CloseTiming

// Only panels opting into hideForCapture close and block capture readiness.
Singleton {
    id: root
    property bool stopping: false
    property var panels: []
    property var owners: []
    readonly property bool active: owners.length > 0
    property var overlays: []
    property var pending: null
    property bool compositorPending: false
    property bool probeNeeded: false
    property int closeGeneration: 0
    signal failed()
    readonly property bool ready: overlays.length === 0 && !compositorPending
    function begin(owner) {
        if (!owners.includes(owner)) owners = owners.concat([owner])
        TooltipService.setCaptureHold(owner, true)
    }
    function end(owner) {
        if (!owners.includes(owner)) return
        owners = owners.filter(item => item !== owner)
        TooltipService.setCaptureHold(owner, false)
    }
    function registerPanel(panel) { panels = panels.concat([panel]) }
    function unregisterPanel(panel) { panels = panels.filter(item => item !== panel); update(panel, false) }
    function prepare() {
        for (const panel of panels.slice()) if (panel.hideForCapture && panel.requested) panel.hide()
    }
    function update(owner, presented) {
        if (stopping) return
        const wasPresented = overlays.includes(owner)
        const others = overlays.filter(item => item !== owner)
        if (compositorPending && presented && !wasPresented) {
            closeGeneration++; closeTimer.stop(); probeNeeded = true
        }
        if (wasPresented && !presented && panels.includes(owner)) {
            compositorPending = true
            probeNeeded = true
            closeGeneration++
            closeTimer.stop()
        }
        overlays = presented ? others.concat([owner]) : others
        startProbe()
        flush()
    }
    function wait(callback) {
        pending = callback
        startProbe()
        flush()
    }
    function cancel(callback = null) { if (!callback || pending === callback) pending = null }
    IpcHandler {
        target: "capture"
        function ready(): bool { root.startProbe(); return root.ready }
    }
    function startProbe() {
        if (stopping || !compositorPending || !probeNeeded || overlays.length || closeProbe.running) return
        probeNeeded = false
        closeProbe.generation = closeGeneration
        closeProbe.running = true
    }
    Component.onDestruction: {
        stopping = true
        pending = null
        closeTimer.stop()
        closeProbe.running = false
    }
    Process {
        id: closeProbe
        property int generation: 0
        command: Config.hyprlandCaptureCloseStateCommand
        stdout: StdioCollector { id: closeState; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: code => {
            if (generation !== root.closeGeneration) { Qt.callLater(root.startProbe); return }
            try {
                if (code !== 0) throw new Error("Compositor state unavailable")
                closeTimer.interval = CloseTiming.milliseconds(JSON.parse(closeState.text))
                closeTimer.generation = generation
                closeTimer.start()
            } catch (_) {
                root.probeNeeded = true
                root.pending = null
                root.failed()
            }
        }
    }
    Timer {
        id: closeTimer
        property int generation: 0
        onTriggered: {
            if (generation !== root.closeGeneration || root.overlays.length || root.probeNeeded) return
            root.compositorPending = false
            root.flush()
        }
    }
    function flush() {
        if (!ready || !pending) return
        // Let the visibility/unmap changes finish before launching the capture tool.
        Qt.callLater(root.deliver)
    }
    function deliver() {
        if (!ready || !pending) return
        const callback = pending
        pending = null
        callback()
    }
}
