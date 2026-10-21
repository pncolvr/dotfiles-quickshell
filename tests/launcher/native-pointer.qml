pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../src/services"
import "../../src/modules/launcher"

WorkerScope {
    id: root
    readonly property var scenarios: ["apps", "webapps", "input", "image", "clipboard", "clipboard-images", "private-menu", "secret", "overview", "image"]
    property int scenario: 0
    readonly property string kind: scenarios[scenario] ?? ""
    readonly property var session: kind.startsWith("clipboard") ? ClipboardPickerService : PickerService
    readonly property var currentWindow: kind.startsWith("clipboard") ? clipboardWindow
        : kind === "overview" ? overview : PickerService.privateWindow ? privateWindow : window
    readonly property bool windowActive: currentWindow.contentItem.Window.active
    property string phase: "open"
    property double phaseStarted: 0
    property var savedPosition: null
    property bool failed: false
    readonly property bool traceFocus: Quickshell.env("POINTER_TEST_TRACE") === "1"
    function trace() {
        if (!traceFocus) return
        const handler = root.find(currentWindow.contentItem,"windowFocusHandler")
        const preview = currentWindow.floatingPreviewWindow
        console.log("POINTER FOCUS:",kind,phase,JSON.stringify({active:windowActive,
            previewVisible:preview?.visible,previewActive:preview?.contentItem.Window.active,
            requesting:handler?.requestingKeyboardFocus,settled:handler?.activationSettled,
            keyboardMode:handler?.keyboardFocusMode}))
    }
    onWindowActiveChanged: trace()
    Test.TestEvent { id: events }
    PickerWindow { id: window }
    PickerWindow { id: clipboardWindow; picker: ClipboardPickerService }
    PrivatePickerWindow { id: privateWindow }
    ExposeWindow { id: overview }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const found = root.find(child, name)
            if (found) return found
        }
        return null
    }
    function fail(message) {
        failed = true
        const handler = root.find(currentWindow.contentItem,"windowFocusHandler")
        console.error("POINTER FAIL:", kind, phase, message, "active:", windowActive, "query:", root.session.query,
            "visible:",root.session.visible,currentWindow.visible,"focus:", currentWindow.contentItem.Window.window?.activeFocusItem?.objectName,
            "handler:",JSON.stringify(handler ? {requested:handler.hostRequestedVisible,ready:handler.ready,
                opening:handler.openingFocus,requesting:handler.requestingKeyboardFocus,settled:handler.activationSettled,
                keyboard:handler.keyboardEnabled,retaining:handler.retainingNativeFocus} : null))
        root.session.close()
        Qt.quit()
    }
    function openCurrent() {
        const mode = kind.startsWith("clipboard") ? PickerService.Mode.Clipboard
            : kind === "secret" ? PickerService.Mode.Secret : kind === "apps" ? PickerService.Mode.Apps
            : kind === "overview" ? PickerService.Mode.Windows : PickerService.Mode.Menu
        root.session.begin(mode,"Synthetic keyboard focus check")
        root.session.privateRequest = kind === "private-menu"
        if (kind === "clipboard-images") root.session.itemCriteria = {kind:"image"}
        root.session.allowTyped = kind === "input"
        root.session.imageOnly = kind === "image"
        root.session.layout = kind === "overview" ? "expose" : "list"
        root.session.items = ["input", "secret", "overview"].includes(kind) ? [] : [{id:"0",title:"Synthetic item",result:"test",
            image:kind === "image" ? Quickshell.shellPath("synthetic.png") : ""}]
        root.session.show()
        trace()
        phaseStarted = Date.now()
        phase = "mapped"
    }
    Process {
        id: placeCursor
        // qmllint disable signal-handler-parameters
        onExited: (code,status) => {
            if (code || status) { root.fail("cursor placement failed"); return }
            root.phase = "baseline"
            cursor.running = true
        }
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: cursor
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector { id: position; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (code,status) => {
            if (code || status) { root.fail("cursor query failed"); return }
            let point
            try { point = JSON.parse(position.text) } catch (_) { root.fail("invalid cursor response"); return }
            if (root.phase === "baseline") {
                root.savedPosition = point
                root.openCurrent()
                return
            }
            if (point.x !== root.savedPosition.x || point.y !== root.savedPosition.y) { root.fail("launcher moved the pointer from " + JSON.stringify(root.savedPosition) + " to " + JSON.stringify(point)); return }
            if (root.phase === "verify-closed") {
                if (++root.scenario === root.scenarios.length) {
                    console.log("PASS: native launcher pointer stays stationary, keyboard focus/search and QR Escape work away from the panel")
                    Qt.quit()
                } else root.phase = "open"
                return
            }
            if (!root.windowActive || (root.kind === "overview" && overview.transitionProgress !== 1)) {
                if (Date.now() - root.phaseStarted > 2500) { root.fail("launcher has no native keyboard focus"); return }
                root.phase = "mapped"
                return
            }
            if (root.kind === "clipboard-images" && !root.currentWindow.panel.floatingPreviewRequested) {
                root.fail("opening Images mode must keep its companion preview enabled"); return
            }
            if (root.kind === "clipboard-images") {
                const card = root.find(root.currentWindow.floatingPreviewWindow.contentItem,"floatingPickerPreview")
                const corner = card?.mapToGlobal(0,0)
                if (!corner || point.x < corner.x || point.x >= corner.x + card.width
                    || point.y < corner.y || point.y >= corner.y + card.height) {
                    root.fail("Images focus regression requires the preview to open beneath the pointer"); return
                }
            }
            if (root.kind === "image") {
                const panel = root.currentWindow.panel
                const topLeft = panel.mapToGlobal(0,0)
                if (point.x >= topLeft.x && point.x < topLeft.x + panel.width
                    && point.y >= topLeft.y && point.y < topLeft.y + panel.height) { root.fail("preview test pointer must be outside the panel"); return }
                if (!panel.panel.activeFocus) { root.fail("image-only panel did not receive keyboard focus"); return }
            } else {
                events.keyClick(Qt.Key_A, Qt.NoModifier, 0)
                if (root.kind === "secret") {
                    const input = root.find(root.currentWindow.previewItem,"secretInput")
                    if (!input?.activeFocus || input.text !== "a") { root.fail("secret prompt did not receive keyboard focus"); return }
                } else if (root.session.query !== "a") { root.fail("keyboard search is unavailable"); return }
            }
            events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
            root.phase = "closed"
            root.phaseStarted = Date.now()
        }
        // qmllint enable signal-handler-parameters
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (root.failed) return
            if (root.phase === "open") {
                const screen = root.session.chooseScreen()
                const monitor = Hyprland.monitorFor(screen)?.lastIpcObject
                if (!monitor) { root.fail("monitor geometry unavailable"); return }
                root.phase = "place"
                placeCursor.command = ["hyprctl","dispatch",`hl.dsp.cursor.move({ x = ${Math.round(monitor.x + screen.width / 2)}, y = ${Math.round(monitor.y + screen.height * 0.85)} })`]
                placeCursor.running = true
            } else if (root.phase === "mapped" && Date.now() - root.phaseStarted >= 220) {
                root.phase = "verify"
                cursor.running = true
            } else if (root.phase === "closed" && Date.now() - root.phaseStarted >= 400) {
                if (root.session.visible) { root.fail("Escape did not close the picker"); return }
                root.phase = "verify-closed"
                cursor.running = true
            }
        }
    }
}
