pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/ui" as UI
import "../../src/bar"

Scope {
    id: root
    property bool submapRequested: false
    property bool otherPanelRequested: true
    FileView { id: closeFailure; path: Quickshell.env("CAPTURE_TEST_DIR") + "/close-state-fail"; blockWrites: true; printErrors: false }
    Test.TestCase { id: events; when: false }
    component Surface: FloatingWindow {
        id: surfaceHost
        color: "transparent"
        property bool requested: false
        property bool blocksCapture: true
        property bool hideForCapture: blocksCapture
        signal captureHideRequested()
        onCaptureHideRequested: {
            if (surfaceHost === launcher) PickerService.close()
            else CaptureMenuService.close()
        }
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
    Surface { id: picker; requested: CaptureMenuService.visible }
    Surface { id: launcher; requested: PickerService.visible; blocksCapture: false }
    Surface { id: submap; requested: root.submapRequested; blocksCapture: false }
    Surface {
        id: notice
        blocksCapture: false
        requested: AlertService.messages.length > 0
        captureRequested: AlertService.messages.some(message => message.captureBlocking)
        presentationPending: transitioning
    }
    FloatingWindow {
        id: other
        visible: root.otherPanelRequested
        implicitWidth: 100; implicitHeight: 100
    }
    QtObject { id: tooltipSource }
    Component { id: tooltipContents; Item {} }
    TooltipFocusHandler {
        id: tooltipFocus
        tooltipWindow: other
        ready: TooltipService.visible
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function waitFor(predicate, message) {
        const deadline = Date.now() + 4000
        while (!predicate() && Date.now() < deadline) events.wait(10)
        check(predicate(), message)
    }
    function result() { return AlertService.messages.find(entry => entry.id === "screenshot") }
    function run() {
        PickerService.promptMenu("Existing Manage", [{title:"Existing entry"}], () => {})
        PickerService.query = "Existing"
        TooltipService.show(100, tooltipContents, tooltipSource, false, other.screen)
        TooltipService.hide() // A queued hover expiry must not beat the keybind.
        ScreenshotService.open()
        check(TooltipService.captureHeld && !tooltipFocus.dismissOnOutside,"chooser protects the existing bar tooltip from focus loss")
        TooltipService.setPanelHovered(false)
        events.wait(500)
        check(TooltipService.visible,"capture chooser preserves bar tooltip through hover expiry")
        check(CaptureMenuService.visible && CaptureMenuService.requestDirectory === "" && !!CaptureMenuService.menuCallback,
            "native choices do not use the shell bridge")
        check(CaptureMenuService.items.map(item => item.title).join(",") === "Ocr,Output,Qrcode,Region,Window", "original five choices")
        CaptureMenuService.query = "out"
        ScreenshotService.open()
        check(CaptureMenuService.query === "out" && CaptureHandoffService.active,"repeated Meta+Print keeps the chooser and capture protection")
        CaptureMenuService.close()
        check(!ScreenshotService.busy && !result() && !TooltipService.captureHeld && TooltipService.visible, "menu cancellation releases capture protection without closing the bar tooltip")
        ScreenshotService.open("invalid")
        check(!ScreenshotService.busy, "unknown method never executes tools")
        // Only opted-in capture controls block readiness; ordinary panels remain open.
        ScreenshotService.open()
        submapRequested = true
        waitFor(() => picker.visible && submap.visible && !picker.transitioning && !submap.transitioning, "overlays presented")
        CaptureMenuService.query = "ocr"
        CaptureMenuService.accept(false, false)
        check(ScreenshotService.busy && !ScreenshotService.job.process && !CaptureMenuService.visible, "logical closure precedes capture")
        check(!CaptureHandoffService.ready, "launcher closing animation still blocks capture")
        waitFor(() => !picker.visible, "capture panel unmaps after its enabled animation")
        check(CaptureHandoffService.compositorPending && !CaptureHandoffService.ready && !ScreenshotService.job.process,
            "unmapped panel still blocks capture during compositor closing animation")
        const unmappedAt = Date.now()
        waitFor(() => !!ScreenshotService.job?.process, "capture starts after panel and compositor closing animations")
        check(Date.now() - unmappedAt >= 180,"configured compositor close is awaited after native unmap")
        check(!picker.visible && submap.visible && other.visible && TooltipService.visible && TooltipService.captureHeld, "bar tooltip, submap and ordinary panels stay open without blocking")
        waitFor(() => !ScreenshotService.busy && result()?.severity === "success", "decoded text receives native success alert")
        check(!TooltipService.captureHeld && TooltipService.visible,"completed capture releases its hold and leaves the bar tooltip open")
        check(PickerService.visible && PickerService.prompt === "Existing Manage" && PickerService.query === "Existing"
            && launcher.visible,"capture preserves the ordinary launcher session and its rendered panel")
        check(result().text.includes("Olá"), "decoded text is preserved in native feedback")
        ScreenshotService.open()
        ScreenshotService.open("ocr")
        check(CaptureHandoffService.active && TooltipService.captureHeld && !CaptureMenuService.visible,
            "direct capture from the chooser keeps protection while closing its controls")
        waitFor(() => !ScreenshotService.busy,"direct chooser handoff finishes")
        launcher.hideForCapture = true
        CaptureHandoffService.prepare()
        check(!PickerService.visible && !CaptureHandoffService.ready,"a panel can opt into closing and waits for its actual closing motion")
        waitFor(() => CaptureHandoffService.ready,"opted-in panel finishes closing")
        launcher.hideForCapture = false
        // A replacement capture menu cancels a queued handoff without closing the replacement.
        AlertService.dismiss("screenshot")
        const launcherGate = {}
        CaptureHandoffService.update(launcherGate,true)
        ScreenshotService.open("qrcode")
        check(ScreenshotService.busy && !ScreenshotService.job.process, "queued operation")
        CaptureMenuService.promptMenu("Replacement", [{title:"Keep working"}], () => {})
        CaptureHandoffService.update(launcherGate,false)
        events.wait(300)
        check(!ScreenshotService.busy && !result() && CaptureMenuService.visible && CaptureMenuService.prompt === "Replacement", "replacement cancels queued capture")
        CaptureMenuService.close()
        waitFor(() => CaptureHandoffService.ready, "all opted-in capture controls close")
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
        check(CaptureHandoffService.ready, "marked bar notices do not block readiness")
        AlertService.dismiss("recording")
        waitFor(() => CaptureHandoffService.ready, "capture notice leaves the shared alert panel")
        check(notice.visible && AlertService.messages.some(message => message.id === "unrelated"), "other alerts remain open")
        AlertService.dismiss("unrelated")
        waitFor(() => !notice.visible && CaptureHandoffService.ready, "alert panel closes")
        AlertService.post("recording", "recording starting", "success", 0, true)
        waitFor(() => notice.visible && !notice.transitioning, "starting notice presented")
        AlertService.dismiss("recording")
        check(CaptureHandoffService.ready, "outgoing bar alert animation does not block capture")
        waitFor(() => !notice.visible && CaptureHandoffService.ready, "notice closes independently of readiness")
        closeFailure.setText("fail")
        AlertService.dismiss("screenshot")
        ScreenshotService.open()
        waitFor(() => picker.visible && !picker.transitioning,"failure fixture opens capture choices")
        CaptureMenuService.query = "ocr"
        CaptureMenuService.accept(false,false)
        waitFor(() => !ScreenshotService.busy && result()?.severity === "error","unavailable compositor state cancels capture")
        check(ScreenshotService.lastAttempt.phase === "waiting" && !CaptureHandoffService.active,
            "failed compositor probe never starts capture or retains its owner")
        closeFailure.setText("")
        ScreenshotService.open()
        waitFor(() => picker.visible && !picker.transitioning,"capture can retry after probe failure")
        CaptureMenuService.query = "ocr"
        CaptureMenuService.accept(false,false)
        waitFor(() => !ScreenshotService.busy && result()?.severity === "success","compositor state recovery permits capture")
        for (const method of ["output", "region", "output"]) {
            ScreenshotService.open(method)
            waitFor(() => !ScreenshotService.busy, "repeated " + method + " completes with QProcess stdin")
            check(ScreenshotService.lastAttempt.result === "editing", "selector receives EOF and hands off to editor: " + method)
        }
        console.log("PASS: repeated region/output workers receive EOF despite the parent QProcess input pipe")
        console.log("PASS: bar submaps, notices and their closing animations never block opt-in capture readiness")
        console.log("PASS: native screenshot choices, real closing-motion handoff, passive-panel preservation, decoding alerts and replacement cancellation")
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            try { root.run() } catch (error) { console.error("CAPTURE FAIL:", error) }
            ScreenshotService.cancel()
            CaptureMenuService.close()
            TooltipService.dismiss()
            root.otherPanelRequested = false
            root.submapRequested = false
            events.wait(50)
            Qt.quit()
        }
    }
}
