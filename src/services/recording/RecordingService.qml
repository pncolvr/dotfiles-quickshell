pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root

    // Operational state is deliberately separate from PipeWire screen sharing/privacy.
    readonly property string state: setup.active || session.launching ? "configuring" : session.state
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
        property bool launching: false
        property double launchDeadline: 0
        property bool cancelAfterLaunch: false
    }

    function toggle() {
        if (!DbService.ready) return false
        if (setup.active) return true
        if (session.launching || session.state === "configuring") { session.cancelAfterLaunch = true; return true }
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
    RecordingSetup {
        id: setup
        onPrepared: options => {
            session.launching = true
            session.launchDeadline = Date.now() + 5000
            // Prepared argument data is passed literally; the worker never reopens a picker.
            Quickshell.execDetached({command: ["bash", root.workerPath, "--run", root.runtimeDatabase,
                Quickshell.shellDir, JSON.stringify(options)], unbindStdout: true})
            Qt.callLater(root.refresh)
        }
        onFailed: message => AlertService.post("recording-control", message, "error", 3000)
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
                if (session.launching) {
                    switch (true) {
                      case result.state !== "idle":
                        session.launching = false
                        break
                      case Date.now() >= session.launchDeadline:
                        session.launching = false
                        session.cancelAfterLaunch = false
                        AlertService.post("recording-control", "Recording could not start", "error", 3000)
                    }
                }
                if (session.cancelAfterLaunch && ["starting", "recording"].includes(result.state)) {
                    session.cancelAfterLaunch = false
                    session.togglePending = true
                }
                if (result.start && !setup.active && !session.launching) setup.open()
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
