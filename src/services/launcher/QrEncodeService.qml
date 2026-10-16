pragma ComponentBehavior: Bound
pragma Singleton

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
        PickerService.promptMenu("Text to encode", [], rows => root.encode(rows[0].result), "list", {
            allowTyped: true, acceptLabel: "Generate QR code"
        })
    }
    function encode(text) {
        if (typeof text !== "string" || !text.trim()) return
        cancel()
        const process = worker.createObject(root, {input: JSON.stringify({text}) + "\n"}) as Process
        job = {process}
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
        cancel()
    }
    function receive(process, data) {
        const operation = job
        if (operation?.process !== process) return
        let response
        try { response = JSON.parse(data) } catch (_) {
            fail(operation, "Could not encode QR code")
            return
        }
        switch (response.status) {
          case "error":
            fail(operation, response.message)
            break
          case "ready": {
            process.ready = true
            AlertService.post("encode-qrcode", "QR code copied to clipboard", "success", 3000)
            previewCallback = () => {}
            PickerService.promptMenu("", [{title: "QR code", result: "close", image: response.image}], previewCallback, "list", {
                imageOnly: true, acceptLabel: "Close", onClosed: () => root.release(operation)
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
                root.fail(root.job, "Could not display QR code")
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
                    if (!ready || code !== 0 || status !== 0) root.fail(operation, "Could not encode QR code")
                    else operation.process = null
                }
                task.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
}
