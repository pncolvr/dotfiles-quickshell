pragma ComponentBehavior: Bound
pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"

Singleton {
    id: root
    property var job: null
    property var lastAttempt: ({})
    function snapshot() {
        return JSON.stringify({busy, ready: CaptureHandoffService.ready, attempt: lastAttempt})
    }
    readonly property bool busy: job !== null
    function open(method = "") {
        if (busy) return
        if (!method) {
            PickerService.promptMenu("", ["ocr", "output", "qrcode", "region", "window"].map(title => ({title})),
                rows => root.open(rows[0].result))
            return
        }
        if (!["region", "output", "window", "ocr", "qrcode"].includes(method)) return
        const operation = {method, process: null, replied: false}
        job = operation
        lastAttempt = {method, phase: "waiting"}
        PickerService.close()
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
            AlertService.post("screenshot", result.message, "info", 3000)
            break
          case "error":
            AlertService.post("screenshot", result.message, "error", 4000)
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
        if (operation?.process?.running) operation.process.signal(15)
    }
    Component.onDestruction: cancel()
    Connections {
        target: PickerService
        function onOpened() { if (root.busy) root.cancel() }
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
                    if (!operation.replied) AlertService.post("screenshot", "Screenshot capture failed", "error", 4000)
                    root.job = null
                }
                task.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
}
