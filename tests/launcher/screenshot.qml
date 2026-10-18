pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/ui" as UI
import "../../src/ui/panels"

Scope {
    id: root
    property bool submapRequested: false
    property bool otherPanelRequested: true
    property double captureUnmappedAt: 0
    Connections {
        target: picker
        function onVisibleChanged() {
            if (!picker.visible) root.captureUnmappedAt = Date.now()
            if (Quickshell.env("CAPTURE_TEST_TRACE")) console.log("CAPTURE VISIBLE", Date.now(), picker.visible, CaptureHandoffService.overlays.length)
        }
    }
    Connections {
        target: CaptureHandoffService
        function onOverlaysChanged() {
            if (Quickshell.env("CAPTURE_TEST_TRACE")) console.log("CAPTURE OVERLAYS", Date.now(), CaptureHandoffService.overlays.length,
                JSON.stringify(CaptureHandoffService.panels.map(panel => ({requested:panel.requested, pending:panel.presentationPending,
                    optedIn:panel.hideForCapture, visible:panel.host.visible}))))
        }
        function onCompositorPendingChanged() {
            if (Quickshell.env("CAPTURE_TEST_TRACE")) console.log("CAPTURE PENDING", Date.now(), CaptureHandoffService.compositorPending)
        }
    }
    FileView { id: closeFailure; path: Quickshell.env("CAPTURE_TEST_DIR") + "/close-state-fail"; blockWrites: true; printErrors: false }
    NativeFocusDriver {
        id: driver
        timeout: 4000
        onFailed: message => { console.error("CAPTURE FAIL:", message); root.finish() }
        onCompleted: root.finish()
    }
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
    function waitFor(predicate, message) { driver.waitFor(message, predicate) }
    function finish() {
        ScreenshotService.cancel()
        CaptureMenuService.close()
        TooltipService.dismiss()
        root.otherPanelRequested = false
        root.submapRequested = false
        Qt.quit()
    }
    function result() { return AlertService.messages.find(entry => entry.id === "screenshot") }
    Component.onCompleted: {
        let called = false
        const launcherGate = {}
        const token = {}
        const abandoned = () => { throw new Error("abandoned handoff ran") }
        const replacement = () => { called = true }
        driver.waitFor("database ready", () => DbService.ready)
        driver.add("capture assertions 1", () => {
            PickerService.promptMenu("Existing Manage", [{title:"Existing entry"}], () => {})
            PickerService.query = "Existing"
            TooltipService.show(100, tooltipContents, tooltipSource, false, other.screen)
            TooltipService.hide() // A queued hover expiry must not beat the keybind.
            ScreenshotService.open()
            check(TooltipService.captureHeld && !tooltipFocus.dismissOnOutside,"chooser protects the existing bar tooltip from focus loss")
            TooltipService.setPanelHovered(false)
        })
        driver.pause(500)
        driver.add("capture assertions 2", () => {
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
        })
        waitFor(() => picker.visible && submap.visible && !picker.transitioning && !submap.transitioning, "overlays presented")
        driver.add("capture assertions 3", () => {
            CaptureMenuService.query = "ocr"
            CaptureMenuService.accept(false, false)
            check(ScreenshotService.busy && !ScreenshotService.job.process && !CaptureMenuService.visible, "logical closure precedes capture")
            check(!CaptureHandoffService.ready, "launcher closing animation still blocks capture")
        })
        waitFor(() => !picker.visible, "capture panel unmaps after its enabled animation")
        driver.add("capture assertions 4", () => {
            check(CaptureHandoffService.compositorPending && !CaptureHandoffService.ready && !ScreenshotService.job.process,
                "unmapped panel still blocks capture during compositor closing animation")
        })
        waitFor(() => !!ScreenshotService.job?.process, "capture starts after panel and compositor closing animations")
        driver.add("capture assertions 5", () => {
            if (Quickshell.env("CAPTURE_TEST_TRACE")) console.log("CAPTURE START", Date.now(), root.captureUnmappedAt)
            check(Date.now() - root.captureUnmappedAt >= 180,"configured compositor close is awaited after native unmap: " + (Date.now() - root.captureUnmappedAt) + "ms")
            check(!picker.visible && submap.visible && other.visible && TooltipService.visible && TooltipService.captureHeld, "bar tooltip, submap and ordinary panels stay open without blocking")
        })
        waitFor(() => !ScreenshotService.busy && result()?.severity === "success", "decoded text receives native success alert")
        driver.add("capture assertions 6", () => {
            check(!TooltipService.captureHeld && TooltipService.visible,"completed capture releases its hold and leaves the bar tooltip open")
            check(PickerService.visible && PickerService.prompt === "Existing Manage" && PickerService.query === "Existing"
                && launcher.visible,"capture preserves the ordinary launcher session and its rendered panel")
            check(result().text.includes("Olá"), "decoded text is preserved in native feedback")
            ScreenshotService.open()
            ScreenshotService.open("ocr")
            check(CaptureHandoffService.active && TooltipService.captureHeld && !CaptureMenuService.visible,
                "direct capture from the chooser keeps protection while closing its controls")
        })
        waitFor(() => !ScreenshotService.busy,"direct chooser handoff finishes")
        driver.add("capture assertions 7", () => {
            launcher.hideForCapture = true
            CaptureHandoffService.prepare()
            check(!PickerService.visible && !CaptureHandoffService.ready,"a panel can opt into closing and waits for its actual closing motion")
        })
        waitFor(() => CaptureHandoffService.ready,"opted-in panel finishes closing")
        driver.add("capture assertions 8", () => {
            launcher.hideForCapture = false
            // A replacement capture menu cancels a queued handoff without closing the replacement.
            AlertService.dismiss("screenshot")
            CaptureHandoffService.update(launcherGate,true)
            ScreenshotService.open("qrcode")
            check(ScreenshotService.busy && !ScreenshotService.job.process, "queued operation")
            CaptureMenuService.promptMenu("Replacement", [{title:"Keep working"}], () => {})
            CaptureHandoffService.update(launcherGate,false)
        })
        driver.pause(300)
        driver.add("capture assertions 9", () => {
            check(!ScreenshotService.busy && !result() && CaptureMenuService.visible && CaptureMenuService.prompt === "Replacement", "replacement cancels queued capture")
            CaptureMenuService.close()
        })
        waitFor(() => CaptureHandoffService.ready, "all opted-in capture controls close")
        driver.add("capture assertions 10", () => {
            // Removing a surface releases its registration, and cancelled callbacks never run.
            CaptureHandoffService.update(token, true)
            CaptureHandoffService.wait(() => { called = true })
            CaptureHandoffService.cancel()
            CaptureHandoffService.update(token, false)
        })
        driver.pause(20)
        driver.add("capture assertions 11", () => {
            check(!called && CaptureHandoffService.ready, "cancelled handoff releases callback")
            CaptureHandoffService.update(token, true)
            CaptureHandoffService.wait(abandoned)
            CaptureHandoffService.wait(replacement)
            CaptureHandoffService.cancel(abandoned)
            CaptureHandoffService.update(token, false)
        })
        waitFor(() => called, "cancelling an old handoff preserves its replacement")
        driver.add("capture assertions 12", () => {
            AlertService.post("unrelated", "Keep this alert", "info", 0)
        })
        waitFor(() => notice.visible && !notice.transitioning, "unrelated alert settles")
        driver.add("capture assertions 13", () => {
            check(CaptureHandoffService.ready, "persistent unrelated alert does not block capture")
            AlertService.post("recording", "recording starting", "success", 0, true)
            check(CaptureHandoffService.ready, "marked bar notices do not block readiness")
            AlertService.dismiss("recording")
        })
        waitFor(() => CaptureHandoffService.ready, "capture notice leaves the shared alert panel")
        driver.add("capture assertions 14", () => {
            check(notice.visible && AlertService.messages.some(message => message.id === "unrelated"), "other alerts remain open")
            AlertService.dismiss("unrelated")
        })
        waitFor(() => !notice.visible && CaptureHandoffService.ready, "alert panel closes")
        driver.add("capture assertions 15", () => {
            AlertService.post("recording", "recording starting", "success", 0, true)
        })
        waitFor(() => notice.visible && !notice.transitioning, "starting notice presented")
        driver.add("capture assertions 16", () => {
            AlertService.dismiss("recording")
            check(CaptureHandoffService.ready, "outgoing bar alert animation does not block capture")
        })
        waitFor(() => !notice.visible && CaptureHandoffService.ready, "notice closes independently of readiness")
        driver.add("capture assertions 17", () => {
            closeFailure.setText("fail")
            AlertService.dismiss("screenshot")
            ScreenshotService.open()
        })
        waitFor(() => picker.visible && !picker.transitioning,"failure fixture opens capture choices")
        driver.add("capture assertions 18", () => {
            CaptureMenuService.query = "ocr"
            CaptureMenuService.accept(false,false)
        })
        waitFor(() => !ScreenshotService.busy && result()?.severity === "error","unavailable compositor state cancels capture")
        driver.add("capture assertions 19", () => {
            check(ScreenshotService.lastAttempt.phase === "waiting" && !CaptureHandoffService.active,
                "failed compositor probe never starts capture or retains its owner")
            closeFailure.setText("")
            ScreenshotService.open()
        })
        waitFor(() => picker.visible && !picker.transitioning,"capture can retry after probe failure")
        driver.add("capture assertions 20", () => {
            CaptureMenuService.query = "ocr"
            CaptureMenuService.accept(false,false)
        })
        waitFor(() => !ScreenshotService.busy && result()?.severity === "success","compositor state recovery permits capture")
        for (const method of ["output", "region", "output"]) {
            driver.add("start " + method, () => ScreenshotService.open(method))
            waitFor(() => !ScreenshotService.busy, "repeated " + method + " completes with QProcess stdin")
            driver.add("editor handoff " + method, () => check(ScreenshotService.lastAttempt.result === "editing", "selector receives EOF and hands off to editor: " + method))
        }
        driver.add("capture assertions 21", () => {
            console.log("PASS: repeated region/output workers receive EOF despite the parent QProcess input pipe")
            console.log("PASS: bar submaps, notices and their closing animations never block opt-in capture readiness")
            console.log("PASS: native screenshot choices, real closing-motion handoff, passive-panel preservation, decoding alerts and replacement cancellation")
        })
        driver.running = true
    }
}
