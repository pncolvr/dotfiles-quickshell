import QtQml
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/config"

Scope {
    id: root
    readonly property var configuration: Config
    readonly property var recording: RecordingService
    IpcHandler {
        target: "fixture"
        function configuration(): string { return root.configuration.testThemeColor }
    }
}
