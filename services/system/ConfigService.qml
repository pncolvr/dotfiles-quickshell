pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"

Singleton {
    id: root

    readonly property string userId: _internal.userId
    QtObject {
        id: _internal
        property string userId: Quickshell.env("EUID") ?? Quickshell.env("UID") ?? "1000"
    }
    Process {
        command: ["id", "-u"]
        running: true
        stdout: SplitParser {
            onRead: data => _internal.userId = data.trim()
        }
    }
}