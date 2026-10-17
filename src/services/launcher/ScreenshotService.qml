pragma ComponentBehavior: Bound
pragma Singleton
import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"

Singleton {
    id: root
    property var job: null
    property bool choosing: false
    property var lastAttempt: ({})
    function snapshot() {
        return JSON.stringify({busy, ready: CaptureHandoffService.ready, attempt: lastAttempt})
    }
    readonly property bool busy: job !== null
    onBusyChanged: if (!busy) CaptureHandoffService.end(root)
    function open(method = "") {
        if (busy || (!method && choosing)) return
        if (!method) {
            choosing = true
            CaptureHandoffService.begin(root)
            CaptureMenuService.promptMenu("", ["ocr", "output", "qrcode", "region", "window"].map(method => ({title:Translations.text("screenshot.modes."+method),result:method})),
                rows => root.open(rows[0].result), "list", {
                    onClosed: reason => {
                        root.choosing = false
                        if (reason !== "accepted" && !root.busy) CaptureHandoffService.end(root)
                    }
                })
            return
        }
        if (!["region", "output", "window", "ocr", "qrcode"].includes(method)) return
        CaptureHandoffService.begin(root)
        const operation = {method, process: null, replied: false}
        job = operation
        lastAttempt = {method, phase: "waiting"}
        CaptureHandoffService.prepare()
        operation.waiter = () => {
            if (root.job !== operation) return
            const process = worker.createObject(root, {method: operation.method}) as Process
            operation.process = process
            root.lastAttempt = {method: operation.method, phase: "running"}
            operation.waiter = null
            process.running = true
        }
        CaptureHandoffService.wait(operation.waiter)
    }
    function receive(process, data) {
        const operation = job
        if (operation?.process !== process) return
        let result
        try { result = JSON.parse(data) } catch (_) { return }
        operation.replied = true
        lastAttempt = Object.assign({}, lastAttempt, {result: result.status,
            reason: result.status === "error" ? result.message : ""})
        switch (result.status) {
          case "ready":
            AlertService.post("screenshot", result.text, "success", 4000)
            break
          case "empty":
            AlertService.post("screenshot", Translations.text(result.message,result.args ?? []), "info", 3000)
            break
          case "error":
            AlertService.post("screenshot", Translations.text(result.message,result.args ?? []), "error", 4000)
            break
          case "cancelled":
          case "editing":
            break
          default:
            operation.replied = false
        }
    }
    function cancel() {
        const operation = job
        if (operation?.waiter) CaptureHandoffService.cancel(operation.waiter)
        job = null
        if (choosing) CaptureMenuService.close()
        CaptureHandoffService.end(root)
        if (operation?.process?.running) operation.process.signal(15)
    }
    Component.onDestruction: cancel()
    Connections {
        target: CaptureMenuService
        function onOpened() { if (root.busy) root.cancel() }
    }
    Connections {
        target: CaptureHandoffService
        function onFailed() {
            if (!root.job?.waiter) return
            root.cancel()
            AlertService.post("screenshot", Translations.text("capture.errors.compositorState"), "error", 4000)
        }
    }
    Component {
        id: worker
        Process {
            id: task
            property string method: ""
            command: ["bash", Quickshell.shellPath("src/services/launcher/providers/screenshot.sh"),
                "--prepared", method, Config.screenshotDirectory, Quickshell.shellDir]
            stdout: SplitParser { onRead: data => root.receive(task, data) }
            stderr: SplitParser { onRead: _data => {} }
            // qmllint disable signal-handler-parameters
            onExited: (code, status) => {
                const operation = root.job
                if (operation?.process === task) {
                    root.lastAttempt = Object.assign({}, root.lastAttempt, {phase: "finished", exitCode: code, exitStatus: status})
                    if (!operation.replied) AlertService.post("screenshot", Translations.text("screenshot.errors.capture"), "error", 4000)
                    root.job = null
                }
                task.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
}
