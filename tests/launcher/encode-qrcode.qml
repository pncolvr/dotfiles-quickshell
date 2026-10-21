pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/theme"

WorkerScope {
    id: root
    property int closures: 0
    Connections { target: PickerService; function onVisibleChanged() { if (!PickerService.visible) root.closures++ } }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        visible: true; implicitWidth: 640; implicitHeight: 500
        PickerPanel { id: panel; anchors.fill: parent }
    }
    FileView {
        id: encoderArgs
        path: Quickshell.env("QR_TEST_DIR") + "/encoder-args"
        preload: false; blockLoading: true; printErrors: false
    }
    FileView {
        id: copyArgs
        path: Quickshell.env("QR_TEST_DIR") + "/copy-args"
        preload: false; blockLoading: true; printErrors: false
    }
    Connections {
        target: PickerService
        function onOpened() {
            if (Quickshell.env("QR_TEST_MODE") === "previewFail" && PickerService.imageOnly)
                PickerService.items = PickerService.menuRows([{title: "QR code", result: "close", image: "data:image/png;base64,invalid"}])
        }
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function waitFor(predicate, message) {
        const deadline = Date.now() + 3000
        while (!predicate() && Date.now() < deadline) events.wait(10)
        check(predicate(), message)
    }
    function alert() { return AlertService.messages.find(message => message.id === "encode-qrcode") }
    function run() {
        const mode = Quickshell.env("QR_TEST_MODE")
        QrEncodeService.open()
        events.wait(20)
        const field = events.findChild(panel, "pickerSearch")
        check(field && field.activeFocus && PickerService.requestDirectory === "", "shared native input is focused without a shell request")
        check(PickerService.items.length === 0 && PickerService.allowTyped && !PickerService.canAccept
            && panel.panel.inputOnly && field.placeholderText === "Text to encode", "compact input and original placeholder")
        switch (mode) {
          case "cancelInput":
            events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
            check(!QrEncodeService.job && !PickerService.visible && !alert(), "input cancellation has no worker or alert")
            console.log("PASS: native QR input cancellation")
            return
          case "emptyInput":
            field.text = "   "
            check(!PickerService.canAccept, "blank input cannot generate a code")
            PickerService.accept(false, false)
            check(!QrEncodeService.job && !alert(), "blank input never encodes")
            PickerService.close()
            console.log("PASS: native QR empty input")
            return
        }
        field.text = Quickshell.env("QR_TEST_TEXT")
        const initialClosures = closures
        events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
        check(PickerService.visible && QrEncodeService.job && closures === initialClosures,
            "generation retains the same open picker")
        check(field.readOnly && !PickerService.canAccept, "pending input cannot be edited or resubmitted")
        switch (mode) {
          case "encodeSlow":
          case "copySlow":
          case "cancelPending":
          case "outsidePending":
          case "reopen": {
            waitFor(() => {
                const state = mode === "copySlow" ? copyArgs : encoderArgs
                state.reload()
                return state.text().length > 0
            }, "tool started before cancellation")
            if (mode === "cancelPending") events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
            else if (mode === "outsidePending") PickerService.close("outside")
            else if (mode === "reopen") QrEncodeService.open()
            else PickerService.promptMenu("Replacement", [{title: "Keep working"}], () => {})
            events.wait(80)
            if (mode === "cancelPending" || mode === "outsidePending") {
                check(!QrEncodeService.job && !PickerService.visible && !alert(), "pending dismissal cancels work without reopening")
                console.log("PASS: native QR pending dismissal", mode)
                return
            }
            check(!QrEncodeService.job && PickerService.visible && !alert(), "pending job cancels without late preview/clipboard/alerts")
            check(mode === "reopen" ? PickerService.prompt === "Text to encode" : PickerService.prompt === "Replacement", "new menu remains intact")
            PickerService.close()
            console.log("PASS: native QR pending cancellation", mode)
            return
          }
          case "oversize":
          case "copyFail":
          case "previewFail": {
            waitFor(() => alert()?.severity === "error", "failure has a native error alert")
            waitFor(() => !QrEncodeService.job && PickerService.visible && !PickerService.imageOnly,
                "failure restores input and releases job")
            const retryField = events.findChild(panel, "pickerSearch")
            check(retryField && !retryField.readOnly && retryField.text === Quickshell.env("QR_TEST_TEXT")
                && PickerService.canAccept && closures === initialClosures,
                "failure preserves editable text for retry without closing the panel")
            const expected = {
                oversize: "Could not encode QR code", copyFail: "Could not copy QR code", previewFail: "Could not display QR code"
            }
            check(alert().text === expected[mode], "failure stage is reported without claiming success")
            console.log("PASS: native QR failure", mode)
            return
          }
        }
        waitFor(() => PickerService.imageOnly && events.findChild(panel, "imageViewer")?.status === Image.Ready, "shared preview loads generated PNG")
        check(closures === initialClosures, "preview replaces pending input without unmapping the picker")
        const viewer = events.findChild(panel, "imageViewer")
        check(!viewer.smooth && !viewer.mipmap && viewer.width > 0 && viewer.width % viewer.implicitWidth === 0,
            "QR modules use whole-pixel scaling without smoothing")
        check(panel.panel.implicitHeight <= Theme.qrPreviewSize && !events.findChild(panel, "pickerSearch"), "compact preview has no search/footer")
        check(alert()?.severity === "success" && alert().text === "QR code copied to clipboard", "copy succeeds before preview")
        check(QrEncodeService.job && PickerService.menuClosedCallback, "in-memory image lifetime is tied to native menu closure")
        switch (mode) {
          case "successEscape": events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0); break
          case "replacePreview": PickerService.promptMenu("Replacement", [{title: "Keep working"}], () => {}); break
          default: events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
        }
        check(!QrEncodeService.job && !PickerService.menuClosedCallback, "preview release callback runs exactly once")
        check(mode === "replacePreview" ? PickerService.prompt === "Replacement" : !PickerService.visible, "closure preserves replacement menu")
        PickerService.close()
        console.log("PASS: native QR shared prompt/viewer, clipboard success, sharp compact preview and close lifecycle", mode)
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            try { root.run() } catch (error) { console.error("QR FAIL:", error) }
            QrEncodeService.cancel()
            PickerService.close()
            events.wait(50)
            Qt.quit()
        }
    }
}
