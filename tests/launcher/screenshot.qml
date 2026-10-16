pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/theme/ui" as UI
import "../../src/bar"

Scope {
    id: root
    property bool submapRequested: false
    property bool otherPanelRequested: true
    Test.TestCase { id: events; when: false }
    component Surface: FloatingWindow {
        id: surfaceHost
        property bool requested: false
        property bool captureRequested: requested
        property bool presentationPending: visible
        readonly property bool transitioning: body.motion.transitioning
        implicitWidth: 500; implicitHeight: 300
        visible: body.presented
        TopPanelSurface {
            id: body
            anchors.fill: parent
            requestedVisible: surfaceHost.requested
            requestedScreen: surfaceHost.screen
            contentWidth: 300; contentHeight: 160
        }
        UI.CaptureOverlay { host: surfaceHost; requested: surfaceHost.captureRequested; presentationPending: surfaceHost.presentationPending }
    }
    Surface { id: picker; requested: PickerService.visible }
    Surface { id: submap; requested: root.submapRequested }
    Surface {
        id: notice
        requested: AlertService.messages.length > 0
        captureRequested: AlertService.messages.some(message => message.captureBlocking)
        presentationPending: transitioning
    }
    FloatingWindow {
        id: other
        visible: root.otherPanelRequested
        implicitWidth: 100; implicitHeight: 100
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function waitFor(predicate, message) {
        const deadline = Date.now() + 4000
        while (!predicate() && Date.now() < deadline) events.wait(10)
        check(predicate(), message)
    }
    function result() { return AlertService.messages.find(entry => entry.id === "screenshot") }
    function run() {
        ScreenshotService.open()
        check(PickerService.visible && PickerService.requestDirectory === "" && !!PickerService.menuCallback,
            "native choices do not use the shell bridge")
        check(PickerService.items.map(item => item.title).join(",") === "ocr,output,qrcode,region,window", "original five choices")
        PickerService.close()
        check(!ScreenshotService.busy && !result(), "menu cancellation is quiet")
        ScreenshotService.open("invalid")
        check(!ScreenshotService.busy, "unknown method never executes tools")
        // Exercise real panel closing motion with a second independently closing overlay.
        ScreenshotService.open()
        submapRequested = true
        waitFor(() => picker.visible && submap.visible && !picker.transitioning && !submap.transitioning, "overlays presented")
        PickerService.query = "ocr"
        PickerService.accept(false, false)
        check(ScreenshotService.busy && !ScreenshotService.job.process && !PickerService.visible, "logical closure precedes capture")
        events.wait(250)
        check(!ScreenshotService.job.process && submap.visible, "submap presentation still blocks capture after picker closes")
        submapRequested = false
        check(!CaptureHandoffService.ready, "closing animation still blocks capture")
        waitFor(() => !!ScreenshotService.job?.process, "capture starts once owned surfaces close")
        check(!picker.visible && !submap.visible && other.visible, "other open panels stay untouched")
        waitFor(() => !ScreenshotService.busy && result()?.severity === "success", "decoded text receives native success alert")
        check(result().text.includes("Olá"), "decoded text is preserved in native feedback")
        // A replacement launcher cancels a queued handoff without closing the replacement.
        AlertService.dismiss("screenshot")
        submapRequested = true
        waitFor(() => submap.visible, "submap reopens")
        ScreenshotService.open("qrcode")
        check(ScreenshotService.busy && !ScreenshotService.job.process, "queued operation")
        PickerService.promptMenu("Replacement", [{title:"Keep working"}], () => {})
        submapRequested = false
        events.wait(300)
        check(!ScreenshotService.busy && !result() && PickerService.visible && PickerService.prompt === "Replacement", "replacement cancels queued capture")
        PickerService.close()
        waitFor(() => CaptureHandoffService.ready, "all capture overlays close")
        // Removing a surface releases its registration, and cancelled callbacks never run.
        const token = {}
        let called = false
        CaptureHandoffService.update(token, true)
        CaptureHandoffService.wait(() => { called = true })
        CaptureHandoffService.cancel()
        CaptureHandoffService.update(token, false)
        events.wait(20)
        check(!called && CaptureHandoffService.ready, "cancelled handoff releases callback")
        const abandoned = () => { throw new Error("abandoned handoff ran") }
        const replacement = () => { called = true }
        CaptureHandoffService.update(token, true)
        CaptureHandoffService.wait(abandoned)
        CaptureHandoffService.wait(replacement)
        CaptureHandoffService.cancel(abandoned)
        CaptureHandoffService.update(token, false)
        waitFor(() => called, "cancelling an old handoff preserves its replacement")
        AlertService.post("unrelated", "Keep this alert", "info", 0)
        waitFor(() => notice.visible && !notice.transitioning, "unrelated alert settles")
        check(CaptureHandoffService.ready, "persistent unrelated alert does not block capture")
        AlertService.post("recording", "recording starting", "success", 0, true)
        check(!CaptureHandoffService.ready, "marked starting notice blocks readiness")
        AlertService.dismiss("recording")
        waitFor(() => CaptureHandoffService.ready, "capture notice leaves the shared alert panel")
        check(notice.visible && AlertService.messages.some(message => message.id === "unrelated"), "other alerts remain open")
        AlertService.dismiss("unrelated")
        waitFor(() => !notice.visible && CaptureHandoffService.ready, "alert panel closes")
        AlertService.post("recording", "recording starting", "success", 0, true)
        waitFor(() => notice.visible && !notice.transitioning, "starting notice presented")
        AlertService.dismiss("recording")
        check(!CaptureHandoffService.ready, "outgoing alert animation still blocks capture")
        waitFor(() => !notice.visible && CaptureHandoffService.ready, "notice completely closes before readiness")
        for (const method of ["output", "region", "output"]) {
            ScreenshotService.open(method)
            waitFor(() => !ScreenshotService.busy, "repeated " + method + " completes with QProcess stdin")
            check(ScreenshotService.lastAttempt.result === "editing", "selector receives EOF and hands off to editor: " + method)
        }
        console.log("PASS: repeated region/output workers receive EOF despite the parent QProcess input pipe")
        console.log("PASS: capture notice blocks through closing motion without blocking on unrelated persistent alerts")
        console.log("PASS: native screenshot choices, real closing-motion handoff, passive-panel preservation, decoding alerts and replacement cancellation")
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            try { root.run() } catch (error) { console.error("CAPTURE FAIL:", error) }
            ScreenshotService.cancel()
            PickerService.close()
            root.submapRequested = false
            events.wait(50)
            Qt.quit()
        }
    }
}
