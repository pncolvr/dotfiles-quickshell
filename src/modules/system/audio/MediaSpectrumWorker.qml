pragma ComponentBehavior: Bound
import "../../../i18n"
import Quickshell.Io
import "../../../theme"
import "../../../config"

Process {
    id: worker
    required property var modelData
    required property bool capturing
    property var frame: Array(Theme.mediaVisualizerPoints).fill(0)
    property var waveform: Array(Theme.mediaVisualizerPoints).fill(0)
    property string error: ""
    signal dataReceived(string data)

    command: Config.mediaSpectrumCommand(String(modelData.properties["object.serial"]),
        Theme.mediaVisualizerPoints, Math.round(1000 / Theme.mediaVisualizerInterval))
    running: capturing
    onRunningChanged: if (running) error = ""
    stdout: SplitParser {
        onRead: data => {
            if (worker.capturing) worker.dataReceived(data);
        }
    }
    stderr: StdioCollector { id: failure; waitForEnd: true }
    // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
    // qmllint disable signal-handler-parameters
    onExited: (exitCode, exitStatus) => {
        worker.frame = Array(Theme.mediaVisualizerPoints).fill(0);
        worker.waveform = Array(Theme.mediaVisualizerPoints).fill(0);
        if (worker.capturing && (exitCode !== 0 || exitStatus !== 0))
            worker.error = failure.text.trim() || Translations.text("media.errors.analysis");
    }
    // qmllint enable signal-handler-parameters
}
