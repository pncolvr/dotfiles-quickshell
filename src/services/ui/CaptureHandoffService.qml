pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io

// Participating picker/submap surfaces and capture notices block until settled.
Singleton {
    id: root
    property var overlays: []
    property var pending: null
    readonly property bool ready: overlays.length === 0
    function update(owner, presented) {
        const others = overlays.filter(item => item !== owner)
        overlays = presented ? others.concat([owner]) : others
        flush()
    }
    function wait(callback) {
        pending = callback
        flush()
    }
    function cancel() { pending = null }
    IpcHandler {
        target: "capture"
        function ready(): bool { return root.ready }
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
