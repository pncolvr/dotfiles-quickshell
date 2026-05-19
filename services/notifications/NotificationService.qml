pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"

// reload with: qs ipc call notifications reload
// toggle with: qs ipc call notifications toggle

Singleton {
    id: root
    readonly property bool dndEnabled: _internal.dndEnabled

    QtObject {
        id: _internal
        property bool dndEnabled: false

        function updateDnd(value) {
            dndEnabled = String(value).toLowerCase().trim() === "true"
        }
    }
    function check() {
        checkProcess.running = true
    }

    function toggle() {
        toggleProcess.running = true
    }

    function openPanel() {
        openPanelProcess.running = true
    }

    Process {
        id: checkProcess
        command: Config.notificationsManagerGetDndCommand
        running: true
        stdout: SplitParser {
            onRead: data => _internal.updateDnd(data)
        }
    }

    Process {
        id: toggleProcess
        command: Config.notificationsManagerToggleDndCommand
        running: false
        stdout: SplitParser {
            onRead: data => _internal.updateDnd(data)
        }
    }

    Process {
        id: openPanelProcess
        command: Config.notificationsManagerOpenPanelCommand
        running: false
    }

    IpcHandler {
        target: "notifications"
        function reload(): void { root.check() }
        function toggle(): void { root.toggle() }
    }
}