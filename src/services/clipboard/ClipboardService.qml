pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"

Singleton {
    id: root
    property bool enabled: false
    property bool paused: PreferencesRepository.value("clipboard.paused", false) === true
    property string error: ""
    property string ignoredId: ""
    property string ignoredText: ""
    readonly property bool monitoring: monitor.running
    readonly property var environment: ({QS_CLIPBOARD_DIRECTORY: Config.clipboardDirectory,
        QS_CLIPBOARD_MAX_BYTES: String(Config.clipboardMaxBytes)})

    function initialize() {
        if (enabled) return
        enabled = Config.clipboardMonitorEnabled
        ClipboardRepository.entries()
        // Capture files are durable; remove leftovers only while no watcher is running.
        run(Config.clipboardCommand.concat(["prune"]), JSON.stringify(ClipboardRepository.entries().map(row => row.id)), () => start())
    }
    function start() { if (enabled && !paused && !monitor.running) monitor.running = true }
    function togglePaused() {
        const next = !paused
        if (!PreferencesRepository.setValue("clipboard.paused", next)) { error = DbService.error; return }
        paused = next
        if (paused) monitor.running = false
        else start()
    }
    function receive(line, imported) {
        let entry
        try { entry = JSON.parse(line) } catch (_) { error = "Invalid response from the clipboard helper."; return }
        if ((paused && !imported) || entry.id === ignoredId) return
        if (ignoredText && entry.kind === "text" && entry.text === ignoredText) {
            if (!ClipboardRepository.entries().some(row => row.id === entry.id)) run(Config.clipboardCommand.concat(["delete", entry.id]))
            return
        }
        const removed = ClipboardRepository.add(entry)
        if (removed === null) { error = DbService.error || "Could not save clipboard history."; return }
        if (removed.length) run(Config.clipboardCommand.concat(["delete"]).concat(removed))
        error = ""
    }
    function remove(id) {
        if (!ClipboardRepository.remove(id)) { error = DbService.error; return }
        run(Config.clipboardCommand.concat(["delete", id]))
    }
    function togglePin(entry) {
        if (!entry) return
        const removed = ClipboardRepository.setPinned(entry.id, !entry.pinned)
        if (removed === null) { error = DbService.error; return }
        if (removed.length) run(Config.clipboardCommand.concat(["delete"]).concat(removed))
        error = ""
    }
    function ignoreTextOnce(text) { ignoredText = text; textIgnoreTimer.restart() }
    function clear() {
        const ids = ClipboardRepository.entries().filter(row => !row.pinned).map(row => row.id)
        if (!ClipboardRepository.clear()) { error = DbService.error; return }
        if (ids.length) run(Config.clipboardCommand.concat(["delete"]).concat(ids))
    }
    function restore(entry, destination, className, paste) {
        const removed = ClipboardRepository.add(entry)
        if (removed?.length) run(Config.clipboardCommand.concat(["delete"]).concat(removed))
        ignoredId = entry.id
        ignoreTimer.restart()
        const command = paste ? Config.clipboardCommand.concat(["paste", entry.id, entry.mime, destination, className])
            : Config.clipboardCommand.concat(["restore", entry.id, entry.mime])
        run(command, "", (success) => {
            if (!success) error = paste ? "Could not paste. Use Copy and paste manually into the destination."
                : "Could not restore the clipboard entry."
        })
    }
    function importCopyq() {
        if (importer.running) return
        error = ""
        importer.running = true
    }
    function run(command, input, callback) {
        const process = task.createObject(root, {command: command, input: input ?? "", callback: callback ?? null})
        process.running = true
    }

    Timer { id: ignoreTimer; interval: 1000; onTriggered: root.ignoredId = "" }
    Timer { id: textIgnoreTimer; interval: 2000; onTriggered: root.ignoredText = "" }
    Timer { id: retry; interval: 5000; onTriggered: root.start() }
    Process {
        id: monitor
        command: Config.clipboardCommand.concat(["watch"])
        environment: root.environment
        stdout: SplitParser { onRead: line => root.receive(line) }
        // Capture stderr internally; clipboard contents never enter shell logs.
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (root.enabled && !root.paused) {
                root.error = "Clipboard monitoring stopped; retrying."
                retry.restart()
            }
        }
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: importer
        command: Config.clipboardCommand.concat(["import-copyq"])
        environment: root.environment
        stdout: SplitParser { onRead: line => root.receive(line, true) }
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) root.error = "Could not import CopyQ history. Ensure CopyQ is running."
        }
        // qmllint enable signal-handler-parameters
    }
    Component {
        id: task
        Process {
            id: process
            property string input: ""
            property var callback: null
            environment: root.environment
            stdinEnabled: true
            stdout: StdioCollector { waitForEnd: true }
            stderr: StdioCollector { waitForEnd: true }
            onStarted: { write(input); stdinEnabled = false }
            // qmllint disable signal-handler-parameters
            onExited: (exitCode, exitStatus) => {
                if (callback) callback(exitCode === 0 && exitStatus === 0)
                process.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
    IpcHandler {
        target: "clipboard"
        function togglePause(): void { root.togglePaused() }
        function importCopyq(): void { root.importCopyq() }
        function state(): string { return JSON.stringify({count: ClipboardRepository.entries().length, monitoring: root.monitoring,
            paused: root.paused, importing: importer.running, error: root.error}) }
    }
}
