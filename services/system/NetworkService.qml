pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root

    readonly property bool online: _internal.online

    QtObject {
        id: _internal
        property bool online: false
    }

    function check() {
        networkCheckProcess.running = true
    }

    Process {
        id: networkCheckProcess
        command: Config.networkCheckCommand
        stdout: SplitParser {
            onRead: data => {
                _internal.online = data.trim() === "1"
            }
        }
        onRunningChanged: {
            if (!running) {
                if (!_internal.online) {
                    AlertService.post("network", "no internet access")
                    retryTimer.start()
                } else {
                    AlertService.dismiss("network")
                }
            }
        }
    }

    Timer {
        id: retryTimer
        interval: Config.networkRetryInterval
        onTriggered: root.check()
    }

    Timer {
        id: periodicTimer
        interval: Config.networkAlertInterval
        running: _internal.online
        repeat: true
        onTriggered: root.check()
    }

    Component.onCompleted: check()
}
