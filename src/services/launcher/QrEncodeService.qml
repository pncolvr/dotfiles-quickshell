pragma ComponentBehavior: Bound
pragma Singleton

import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import "../"

Singleton {
    id: root
    property var job: null
    property var previewCallback: null

    function open() {
        cancel()
        input()
    }
    function input(text = "") {
        PickerService.promptMenu(Translations.text("qr.fields.text"), [], rows => root.encode(rows[0].result), "list", {
            promptKey: "qr",
            allowTyped: true, keepOpen: true, query: text, acceptLabel: Translations.text("qr.actions.generate")
        })
    }
    function encode(text) {
        if (typeof text !== "string" || !text.trim()) return
        cancel()
        const process = worker.createObject(root, {input: JSON.stringify({text}) + "\n"}) as Process
        const operation = {process, text}
        job = operation
        const callback = () => {}
        previewCallback = callback
        PickerService.promptMenu(Translations.text("qr.fields.text"), [], callback, "list", {
            promptKey: "qr",
            allowTyped: true, keepOpen: true, query: text, busy: true,
            acceptLabel: Translations.text("qr.actions.generate"),
            onClosed: () => {
                if (root.job === operation && root.previewCallback === callback) root.cancel()
            }
        })
        process.running = true
    }
    function release(operation, abort = false) {
        if (job !== operation) return
        job = null
        previewCallback = null
        const process = operation.process
        operation.process = null
        if (!process) return
        process.stdinEnabled = false
        if (abort && process.running) process.signal(15)
    }
    function cancel() {
        if (!job) return
        const ownsPreview = previewCallback && PickerService.menuCallback === previewCallback
        release(job, true)
        if (ownsPreview) PickerService.close()
    }
    function fail(operation, message) {
        if (job !== operation) return
        AlertService.post("encode-qrcode", message, "error", 3000)
        const ownsPanel = previewCallback && PickerService.menuCallback === previewCallback
        release(operation, true)
        if (ownsPanel) input(operation.text)
    }
    function receive(process, data) {
        const operation = job
        if (operation?.process !== process) return
        let response
        try { response = JSON.parse(data) } catch (_) {
            fail(operation, Translations.text("qr.errors.encode"))
            return
        }
        switch (response.status) {
          case "error":
            fail(operation, Translations.text(response.message,response.args ?? []))
            break
          case "ready": {
            process.ready = true
            AlertService.post("encode-qrcode", Translations.text("qr.status.copied"), "success", 3000)
            previewCallback = () => {}
            PickerService.promptMenu("", [{title: Translations.text("qr.title"), result: "close", image: response.image}], previewCallback, "list", {
            promptKey: "qr",
                imageOnly: true, keepOpen: true, acceptLabel: Translations.text("common.actions.close"), onClosed: () => root.release(operation)
            })
            break
          }
        }
    }
    Component.onDestruction: if (job?.process) { job.process.stdinEnabled = false; job.process.signal(15) }

    Connections {
        target: PickerService
        function onOpened() {
            if (root.job && (!root.previewCallback || PickerService.menuCallback !== root.previewCallback)) root.cancel()
        }
        function onImagePreviewFailed() {
            if (root.job && root.previewCallback && PickerService.menuCallback === root.previewCallback)
                root.fail(root.job, Translations.text("qr.errors.display"))
        }
    }
    Component {
        id: worker
        Process {
            id: task
            property string input: ""
            property bool ready: false
            command: ["bash", Quickshell.shellPath("src/services/launcher/qr-encode.sh")]
            stdinEnabled: true
            onStarted: { if (stdinEnabled) write(input); input = ""; stdinEnabled = false }
            stdout: SplitParser { onRead: data => root.receive(task, data) }
            stderr: SplitParser { onRead: _data => {} }
            // qmllint disable signal-handler-parameters
            onExited: (code, status) => {
                const operation = root.job
                if (operation?.process === task) {
                    if (!ready || code !== 0 || status !== 0) root.fail(operation, Translations.text("qr.errors.encode"))
                    else operation.process = null
                }
                task.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
}
