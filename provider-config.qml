// Read-only offline export; the launcher owns the private FIFO and process lifetime.
import QtQml
import Quickshell
import Quickshell.Io
import "src/config"

Scope {
    Process {
        id: reply
        command: Config.pickerBridgeCommand.concat(["reply", Quickshell.env("QS_PROVIDER_CONFIG_REQUEST") ?? ""])
        stdinEnabled: true
        onStarted: {
            write(JSON.stringify(Config.providerEnvironment) + "\n")
            stdinEnabled = false
        }
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: Qt.quit()
        // qmllint enable signal-handler-parameters
    }
    Component.onCompleted: {
        Quickshell.watchFiles = false
        reply.running = true
    }
}
