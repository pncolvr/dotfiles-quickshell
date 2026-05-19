pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../../config"

Singleton {
    id: root

    readonly property string submapName: HyprlandEventsService.submapName
    readonly property bool submapActive: submapName !== ""
    readonly property var keybinds: _internal.keybinds

    QtObject {
        id: _internal
        property var keybinds: []
    }

    Connections {
        target: HyprlandEventsService
        function onSubmapNameChanged() {
            _internal.keybinds = []
            if (root.submapName !== "") {
                submapProcess.command = [Config.submapParserCommand, root.submapName]
                submapProcess.running = true
            }
        }
    }

    Process {
        id: submapProcess
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (!line) return
                const idx = line.indexOf(";")
                if (idx > 0) {
                    _internal.keybinds = [..._internal.keybinds, {
                        key: line.substring(0, idx),
                        action: line.substring(idx + 1)
                    }]
                }
            }
        }
    }
}
