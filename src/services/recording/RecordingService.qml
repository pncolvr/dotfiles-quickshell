pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root

    // Operational state is deliberately separate from PipeWire screen sharing/privacy.
    readonly property string state: session.state
    readonly property bool active: ["recording", "stopping", "recovering"].includes(state)
    readonly property bool busy: state !== "idle"
    readonly property string filename: session.filename
    readonly property string runtimeDatabase: Config.databasePath.slice(0, Config.databasePath.lastIndexOf("/")) + "/recording-runtime.db"
    readonly property string workerPath: Quickshell.shellPath("src/services/recording/recording-worker.sh")

    QtObject {
        id: session
        property string state: "idle"
        property string filename: ""
        property bool togglePending: false
    }

    function toggle() {
        if (!DbService.ready) return false
        session.togglePending = true
        refresh()
        return true
    }
    function refresh() {
        if (!DbService.ready || controller.running) return
        const action = session.togglePending ? "--toggle" : "--status"
        session.togglePending = false
        controller.requestedToggle = action === "--toggle"
        controller.command = ["bash", workerPath, action, runtimeDatabase, Quickshell.shellDir]
        controller.running = true
    }
    Timer {
        id: poll
        interval: root.busy ? 250 : 5000
        running: DbService.ready
        repeat: true
        onTriggered: root.refresh()
    }
    Process {
        id: controller
        property bool requestedToggle: false
        stdout: StdioCollector {
            onStreamFinished: {
                let result
                try { result = JSON.parse(text) } catch (_) { return }
                session.state = result.state
                session.filename = result.filename
                if (result.start) {
                    session.state = "configuring"
                    // The child owns its recorder and cleanup across bar/theme/config reloads.
                    Quickshell.execDetached({command: ["bash", root.workerPath, "--run",
                        root.runtimeDatabase, Quickshell.shellDir], unbindStdout: true})
                }
            }
        }
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (code, status) => {
            if ((code !== 0 || status !== 0) && controller.requestedToggle)
                AlertService.post("recording-control", "Recording control failed; retry the shortcut.", "error", 3000)
            if (session.togglePending) Qt.callLater(root.refresh)
        }
        // qmllint enable signal-handler-parameters
    }
    Connections { target: DbService; function onReadyChanged() { root.refresh() } }
    Component.onCompleted: refresh()
    IpcHandler {
        target: "recording"
        function toggle(): bool { return root.toggle() }
        function status(): string { return JSON.stringify({state: root.state, active: root.active, filename: root.filename}) }
    }
}
