pragma Singleton
pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../"
import "../../config"
Singleton {
    id: root
    readonly property bool enabled: Config.vaultEnabled
    onEnabledChanged: if (!enabled) close()
    property bool visible: false
    property bool busy: false
    property string activeAction: ""
    property string selectedId: ""
    property int selectionGeneration: 0
    onSelectedIdChanged: selectionGeneration++
    readonly property bool selecting: busy && activeAction === "detail"
    property bool checkingLock: false
    property bool reloadAfterPending: false
    property string error: ""
    property var targetScreen: null
    property var entries: []
    property var detail: null
    property string baseline: ""
    property int generation: 0
    property var clipboardOwner: null
    readonly property var workerEnvironment: ({RUST_LOG: "off", BASH_ENV: ""})
    readonly property var folders: [...new Set(entries.map(row => row.folder).filter(Boolean))].sort()
    signal cleared()
    signal detailsLoaded()
    signal saved()
    signal generated(string password)
    signal copied()
    function clear() { detail = null; baseline = ""; selectedId = ""; cleared() }
    function open() {
        if (!enabled) return
        if (visible) { close(); return }
        PickerService.close()
        targetScreen = Quickshell.screens.find(output => output.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0] || null
        generation++
        visible = true
        error = ""
        entries = []
        clear()
        reloadAfterPending = busy
        if (!busy) request({action: "list"})
    }
    function close() { reloadAfterPending = false; visible = false; generation++; entries = []; error = ""; clear() }
    function reload(sync) { if (busy) return; clear(); request({action: sync ? "sync" : "list"}) }
    function select(id) {
        if (!visible || (busy && activeAction !== "detail" && activeAction !== "totp")) return
        const wanted = id || ""
        if (selectedId === wanted && (busy || detail?.id === wanted)) return
        if (!wanted) { clear(); return }
        selectedId = wanted
        baseline = ""
        if (!busy && wanted) request({action: "detail", id: wanted})
    }
    function save(draft) {
        if (!draft) return
        const message = Object.assign({}, draft, {action: draft.id ? "edit" : "add", baseline})
        if (draft.id && draft.id !== selectedId) return
        request(message)
    }
    function remove() { if (detail && detail.id === selectedId) request({action: "remove", id: detail.id, baseline}) }
    function generate(length) { request({action: "generate", length}) }
    function copyTotp() {
        if (!detail || detail.id !== selectedId || !detail.data?.totp) return
        request({action: "totp", id: selectedId})
    }
    function copy(value) {
        if (!value) return
        clipboardOwner = SensitiveClipboardService.copy(value, 30000, success => {
            if (success === false) root.error = Translations.text("vault.errors.copy")
        })
        copied()
    }
    function lock() { if (busy) return; generation++; entries = []; clear(); request({action: "lock"}) }
    function checkLock() {
        if (!enabled || !visible || busy || checkingLock || !entries.length) return
        checkingLock = true
        startTask({action: "unlocked"})
    }
    function startTask(message) {
        const process = task.createObject(root, {input: JSON.stringify(message) + "\n", action: message.action, entryId: message.id || "", epoch: generation, selectionEpoch: selectionGeneration}) as Process
        process.running = true
    }
    function request(message) {
        if (!enabled || busy || !visible) return false
        activeAction = message.action
        busy = true
        error = ""
        startTask(message)
        return true
    }
    function receive(message, action, epoch, entryId, selectionEpoch) {
        const background = action === "unlocked"
        if (background) checkingLock = false
        else { activeAction = ""; busy = false }
        if (!visible || epoch !== generation) {
            if (!background && visible && reloadAfterPending) { reloadAfterPending = false; request({action: "list"}) }
            return
        }
        // A search may choose another entry while this read is in progress.
        // Discard its reply and load only the latest selected entry.
        if ((action === "detail" || action === "totp")
            && (entryId !== selectedId || (action === "totp" && selectionEpoch !== selectionGeneration))) {
            if (selectedId) request({action: "detail", id: selectedId})
            return
        }
        if (!message || message.ok !== true) {
            if (background) { generation++; reloadAfterPending = false; entries = []; clear(); error = Translations.text("vault.errors.lockState") }
            else {
                if (action === "detail") clear()
                error = Translations.text(message?.error) || Translations.text("vault.errors.operation")
            }
            return
        }
        if (action === "totp") {
            if (typeof message.token !== "string" || !/^(?:[0-9]{1,10}|[23456789BCDFGHJKMNPQRTVWXY]{5})$/.test(message.token)) {
                error = Translations.text("vault.errors.totpResponse")
                return
            }
            if (detail?.id === entryId) copy(message.token)
            return
        }
        if (message.entries) entries = message.entries
        if (message.entry) { detail = message.entry; baseline = message.baseline; detailsLoaded() }
        if (typeof message.password === "string") generated(message.password)
        if (message.saved) { clear(); saved(); request({action: "list"}) }
        if (message.locked || message.unlocked === false) {
            generation++; reloadAfterPending = false; entries = []; clear()
            SensitiveClipboardService.stop(clipboardOwner)
            error = Translations.text("vault.errors.locked")
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.visible
        onTriggered: root.checkLock()
    }
    Component {
        id: task
        Process {
            id: process
            property string input: ""
            property string action: ""
            property string entryId: ""
            property int epoch: 0
            property int selectionEpoch: 0
            command: ["bash", Quickshell.shellPath("src/services/vault/rbw-manager.sh")]
            environment: root.workerEnvironment
            stdinEnabled: true
            onStarted: { write(input); input = ""; stdinEnabled = false }
            stdout: StdioCollector { id: output; waitForEnd: true }
            stderr: SplitParser { onRead: _data => {} }
            // qmllint disable signal-handler-parameters
            onExited: (exitCode, exitStatus) => {
                let response = null
                if (exitCode === 0 && exitStatus === 0) {
                    try { response = JSON.parse(output.text) } catch (_) {}
                }
                root.receive(response, action, epoch, entryId, selectionEpoch)
                process.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
    Connections {
        target: SensitiveClipboardService
        function onReleased(owner: var) { if (root.clipboardOwner === owner) root.clipboardOwner = null }
    }
    IpcHandler { target: "vault"; function toggle(): void { root.open() } }
}
