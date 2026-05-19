pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"

// reload with: qs ipc call status reload

Singleton {
    id: root

    readonly property string status: _internal.status
    readonly property string source: _internal.source
    
    QtObject {
        id: _internal
        property string status: ""
        property string source: ""
    }
    function reload() {
        checkProcess.running = true
        sourceProcess.running = true
    }

    function toggle() {
        toggleProcess.running = true
    }

    function clear() {
        clearProcess.running = true
    }

    Process {
        id: checkProcess
        command: Config.statusManagerCheckCommand
        running: true
        stdout: SplitParser {
            onRead: data => {
                _internal.status = data
            }
        }
    }

    Process {
        id: sourceProcess
        command: Config.statusManagerSourceCommand
        running: true
        stdout: SplitParser {
            onRead: data => {
                _internal.source = data
            }
        }
    }

    Process {
        id: toggleProcess
        command: Config.statusManagerToggleCommand
        onRunningChanged: if (!running) root.reload()
    }

    Process {
        id: clearProcess
        command: Config.statusManagerClearCommand
        onRunningChanged: if (!running) root.reload()
    }

    IpcHandler {
        target: "status"
        function reload(): void { root.reload() }
    }
}