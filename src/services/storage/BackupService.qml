pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root
    readonly property bool visible: PickerService.visible && PickerService.secretActions === root
    property bool busy: false
    readonly property bool generating: generator.running
    readonly property bool creating: action === "export"
    property bool awaitingPassword: false
    property string action: ""
    property string path: ""
    property string outputPath: ""
    property string error: ""
    property string phase: ""
    property string recovery: ""
    property var importReport: null
    readonly property var lastRestore: importReport ?? PreferencesRepository.value("backup.lastRestore", null)
    property string pendingInput: ""
    property bool completed: false
    property bool recoveryRequired: false
    property int waitTicks: 0
    property int epoch: 0
    readonly property var workerEnvironment: ({BASH_ENV: ""})
    signal generated(string password)
    signal restored()

    function open(operation, filename) {
        if (busy || visible || recoveryRequired || !DbService.ready || !filename.trim()) return false
        if (operation === "export" && !filename.endsWith(".7z")) return false
        RbwService.close()
        TooltipService.dismiss()
        action = operation
        path = filename
        outputPath = ""
        completed = false
        AlertService.dismiss("backup")
        error = ""
        phase = ""
        recovery = ""
        importReport = null
        epoch++
        awaitingPassword = true
        PickerService.promptSecret(creating ? "Create backup" : "Restore backup",
            filename + (creating ? "\nDatabase, clipboard history and TOTP secrets"
                : "\nReplaces saved data and TOTP entries, then reloads the shell."), root,
            value => { if (value === null) root.cancel(); else root.submit(value) })
        return true
    }
    function cancel() {
        if (busy) return
        awaitingPassword = false
        epoch++
        error = ""
        pendingInput = ""
    }
    function generate() {
        if (visible && creating && !generator.running) {
            generator.epoch = epoch
            generator.stdinEnabled = true
            generator.running = true
        }
    }
    function copy(password) {
        if (!visible || !password) return
        SensitiveClipboardService.copy(password, 0, success => {
            if (visible) PickerService.error = success === false ? "Could not copy password." : ""
        })
    }
    function submit(password) {
        if (!awaitingPassword || busy || !password || password.length > 1024 || /[\x00-\x1f\x7f]/.test(password)) return false
        pendingInput = JSON.stringify({action, path, password, database: Config.databasePath,
            clipboard: Config.clipboardDirectory, schema: DbService.schemaVersion, totpCommand: Config.totpCommand}) + "\n"
        completed = false
        error = ""
        busy = true
        awaitingPassword = false
        phase = action === "export" ? "backup: preparing" : "restore: preparing"
        AlertService.post("backup", phase, "info")
        TotpService.maintenance = true
        ClipboardService.beginMaintenance()
        waitTicks = 0
        settle.start()
        return true
    }
    function release() {
        DbService.maintenance = false
        TotpService.maintenance = false
        ClipboardService.endMaintenance()
        pendingInput = ""
        busy = false
    }
    function fail(message) {
        error = message
        phase = message
        AlertService.post("backup", message, "error", 60000)
    }
    function receive(line) {
        let message
        try { message = JSON.parse(line) } catch (_) { fail("Invalid response from the backup helper."); return }
        if (message.type === "progress") {
            phase = message.message
            AlertService.post("backup", phase, "info")
        } else if (message.type === "error") {
            recoveryRequired = message.recoveryRequired === true
            fail(message.message)
        }
        else if (message.type === "done") {
            completed = true
            recovery = message.recovery ?? ""
            importReport = message.report ?? null
            outputPath = message.path ?? ""
        }
    }
    Timer {
        interval: 100
        running: !root.busy && !DbService.maintenance && PreferencesRepository.value("backup.lastRestore", null)?.pendingNotice === true
        onTriggered: {
            const report = PreferencesRepository.value("backup.lastRestore", null)
            if (!report) return
            root.recovery = report.recovery ?? ""
            root.phase = report.summary ?? "backup restored"
            AlertService.post("backup", root.phase, report.warningCount > 0 ? "warning" : "success", report.warningCount > 0 ? 10000 : 4000)
            PreferencesRepository.setValue("backup.lastRestore", Object.assign({},report,{pendingNotice:false}))
        }
    }
    Timer {
        id: settle
        interval: 50
        repeat: true
        onTriggered: {
            if (++root.waitTicks > 600) {
                stop()
                root.release()
                root.fail("Backup could not start while another clipboard or TOTP operation was running.")
            } else if (ClipboardService.settled && TotpService.stopped) {
                stop()
                DbService.maintenance = true
                worker.stdinEnabled = true
                worker.running = true
            }
        }
    }
    Process {
        id: generator
        property int epoch: 0
        command: Config.backupCommand
        environment: root.workerEnvironment
        stdinEnabled: true
        onStarted: { write('{"action":"generate"}\n'); stdinEnabled = false }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const result = JSON.parse(line)
                    if (root.visible && generator.epoch === root.epoch && result.type === "generated") root.generated(result.password)
                } catch (_) { if (root.visible) PickerService.error = "Password generation failed." }
            }
        }
        stderr: SplitParser { onRead: _data => {} }
        // qmllint disable signal-handler-parameters
        onExited: (code, status) => {
            if (root.visible && (code !== 0 || status !== 0)) PickerService.error = "Password generation failed."
        }
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: worker
        command: Config.backupCommand
        environment: root.workerEnvironment
        stdinEnabled: true
        onStarted: { write(root.pendingInput); root.pendingInput = ""; stdinEnabled = false }
        stdout: SplitParser { onRead: line => root.receive(line) }
        stderr: SplitParser { onRead: _data => {} }
        // qmllint disable signal-handler-parameters
        onExited: (code, status) => {
            if (!root.completed || code !== 0 || status !== 0) {
                if (!root.error) root.fail("Backup operation failed. Check dependencies and file permissions.")
                if (root.recoveryRequired) { root.pendingInput = ""; root.busy = false }
                else root.release()
                return
            }
            root.phase = root.creating ? "backup created" : (root.importReport?.summary ?? "backup restored") + "; reloading"
            AlertService.post("backup", root.creating ? "Backup created: " + root.outputPath : root.phase,
                root.importReport?.warningCount > 0 ? "warning" : "success", root.creating ? 15000 : 4000)
            if (root.action === "import") {
                // Keep stale models and callbacks from writing until reload.
                root.restored()
            } else root.release()
        }
        // qmllint enable signal-handler-parameters
    }
    IpcHandler {
        target: "backup"
        function create(path: string): bool { return root.open("export", path) }
        function restore(path: string): bool { return root.open("import", path) }
        function status(): string { return JSON.stringify({busy: root.busy, prompting: root.visible,
            action: root.action, path: root.path, phase: root.phase, error: root.error,
            completed: root.completed && !root.busy && !root.error, output: root.outputPath,
            recovery: root.recovery || root.lastRestore?.recovery || "", report: root.lastRestore}) }
    }
}
