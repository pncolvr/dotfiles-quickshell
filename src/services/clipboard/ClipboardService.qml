pragma Singleton
pragma ComponentBehavior: Bound

import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"

Singleton {
    id: root
    property bool enabled: false
    property bool initialized: false
    property bool initializing: false
    property bool paused: PreferencesRepository.value("clipboard.paused", false) === true
    property string error: ""
    property string ignoredId: ""
    property string ignoredText: ""
    property bool maintenance: false
    property int pendingTasks: 0
    readonly property bool settled: !initializing && pendingTasks === 0 && !monitor.running && !importer.running
    readonly property bool monitoring: monitor.running
    readonly property var environment: ({QS_CLIPBOARD_DIRECTORY: Config.clipboardDirectory,
        QS_CLIPBOARD_MAX_BYTES: String(Config.clipboardMaxBytes)})

    function initialize() {
        if (initialized || initializing) return
        enabled = Config.clipboardMonitorEnabled
        const entries = ClipboardRepository.ids()
        if (entries === null) { error = DbService.error; retry.restart(); return }
        // Capture files are durable; remove leftovers only while no watcher is running.
        initializing = true
        run(Config.clipboardCommand.concat(["prune"]), JSON.stringify(entries.map(row => row.id)), success => {
            initializing = false
            if (!success) { error = Translations.text("clipboard.errors.cleanup"); retry.restart(); return }
            initialized = true
            error = ""
            start()
        })
    }
    function start() {
        if (maintenance) return
        if (!initialized) { initialize(); return }
        if (enabled && !paused && !monitor.running) monitor.running = true
    }
    function togglePaused() {
        if (maintenance) return
        const next = !paused
        if (!PreferencesRepository.setValue("clipboard.paused", next)) { error = DbService.error; return }
        paused = next
        if (paused) monitor.running = false
        else start()
    }
    function receive(line, imported) {
        let entry
        try { entry = JSON.parse(line) } catch (_) { error = Translations.text("clipboard.errors.invalidResponse"); return }
        if ((maintenance && !imported) || (paused && !imported) || entry.id === ignoredId) return
        if (ignoredText && entry.kind === "text" && entry.text === ignoredText) {
            if (DbService.ready && !ClipboardRepository.contains(entry.id)) run(Config.clipboardCommand.concat(["delete", entry.id]))
            return
        }
        const removed = ClipboardRepository.add(entry)
        if (removed === null) { error = DbService.error || Translations.text("clipboard.errors.save"); return }
        if (removed.length) run(Config.clipboardCommand.concat(["delete"]).concat(removed))
        error = ""
    }
    function remove(id) {
        if (maintenance) return
        if (!ClipboardRepository.remove(id)) { error = DbService.error; return }
        run(Config.clipboardCommand.concat(["delete", id]))
    }
    function togglePin(entry) {
        if (maintenance) return
        if (!entry) return
        const removed = ClipboardRepository.setPinned(entry.id, !entry.pinned)
        if (removed === null) { error = DbService.error; return }
        if (removed.length) run(Config.clipboardCommand.concat(["delete"]).concat(removed))
        error = ""
    }
    function ignoreTextOnce(text) { ignoredText = text; textIgnoreTimer.restart() }
    function clear() {
        if (maintenance) return
        const entries = ClipboardRepository.ids(true)
        if (entries === null) { error = DbService.error; return }
        const ids = entries.map(row => row.id)
        if (!ClipboardRepository.clear()) { error = DbService.error; return }
        if (ids.length) run(Config.clipboardCommand.concat(["delete"]).concat(ids))
    }
    function restore(entry, destination, className, paste) {
        if (maintenance) return
        const removed = ClipboardRepository.touch(entry.id)
        if (removed?.length) run(Config.clipboardCommand.concat(["delete"]).concat(removed))
        ignoredId = entry.id
        ignoreTimer.restart()
        const command = paste ? Config.clipboardCommand.concat(["paste", entry.id, entry.mime, destination, className])
            : Config.clipboardCommand.concat(["restore", entry.id, entry.mime])
        run(command, "", (success) => {
            if (!success) error = Translations.text(paste ? "clipboard.errors.paste" : "clipboard.errors.restore")
        })
    }
    function importCopyq() {
        if (maintenance || importer.running) return
        error = ""
        importer.running = true
    }
    function run(command, input, callback) {
        pendingTasks++
        const process = task.createObject(root, {command: command, input: input ?? "", callback: callback ?? null}) as Process
        process.running = true
    }
    function beginMaintenance() {
        maintenance = true
        retry.stop()
        // SIGTERM lets the watcher reap its capture process groups before exit.
        if (monitor.running) monitor.signal(15)
    }
    function endMaintenance() { maintenance = false; start() }

    Timer { id: ignoreTimer; interval: 1000; onTriggered: root.ignoredId = "" }
    Timer { id: textIgnoreTimer; interval: 2000; onTriggered: root.ignoredText = "" }
    Connections {
        target: DbService
        function onReadyChanged() { if (DbService.ready) root.initialize() }
        function onErrorChanged() { if (!DbService.ready && DbService.error) root.error = DbService.error }
    }
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
            if (root.enabled && !root.paused && !root.maintenance) {
                root.error = Translations.text("clipboard.errors.monitoring")
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
            if (exitCode !== 0 || exitStatus !== 0) root.error = Translations.text("clipboard.errors.copyqImport")
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
                root.pendingTasks--
                process.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
    IpcHandler {
        target: "clipboard"
        function togglePause(): void { root.togglePaused() }
        function importCopyq(): void { root.importCopyq() }
        function state(): string { return JSON.stringify({count: ClipboardRepository.count(), monitoring: root.monitoring,
            paused: root.paused, importing: importer.running, error: root.error}) }
    }
}
