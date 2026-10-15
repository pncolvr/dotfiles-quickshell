pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../src/services"
import "../../src/modules/launcher"

Scope {
    id: root
    readonly property var scenarios: ["apps", "webapps", "input", "image", "clipboard", "clipboard-images", "private-menu", "secret", "overview", "image"]
    property int scenario: 0
    readonly property string kind: scenarios[scenario] ?? ""
    readonly property var currentWindow: kind === "overview" ? overview : PickerService.privateWindow ? privateWindow : window
    readonly property bool windowActive: currentWindow.contentItem.Window.active
    property string phase: "open"
    property double phaseStarted: 0
    property var savedPosition: null
    property bool failed: false
    Test.TestEvent { id: events }
    PickerWindow { id: window }
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
        console.error("POINTER FAIL:", kind, phase, message, "active:", windowActive, "query:", PickerService.query,
            "focus:", currentWindow.contentItem.Window.window?.activeFocusItem?.objectName)
        PickerService.close()
        Qt.quit()
    }
    function openCurrent() {
        const mode = kind.startsWith("clipboard") ? PickerService.Mode.Clipboard
            : kind === "secret" ? PickerService.Mode.Secret : kind === "apps" ? PickerService.Mode.Apps
            : kind === "overview" ? PickerService.Mode.Windows : PickerService.Mode.Menu
        PickerService.begin(mode,"Synthetic keyboard focus check")
        PickerService.privateRequest = kind === "private-menu"
        if (kind === "clipboard-images") PickerService.itemCriteria = {kind:"image"}
        PickerService.allowTyped = kind === "input"
        PickerService.imageOnly = kind === "image"
        PickerService.layout = kind === "overview" ? "expose" : "list"
        PickerService.items = ["input", "secret", "overview"].includes(kind) ? [] : [{id:"0",title:"Synthetic item",result:"test",
            image:kind === "image" ? Quickshell.shellPath("synthetic.png") : ""}]
        PickerService.show()
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
                } else if (PickerService.query !== "a") { root.fail("keyboard search is unavailable"); return }
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
                const screen = PickerService.chooseScreen()
                const monitor = Hyprland.monitorFor(screen)?.lastIpcObject
                if (!monitor) { root.fail("monitor geometry unavailable"); return }
                root.phase = "place"
                placeCursor.command = ["hyprctl","dispatch",`hl.dsp.cursor.move({ x = ${Math.round(monitor.x + screen.width / 2)}, y = ${Math.round(monitor.y + screen.height * 0.85)} })`]
                placeCursor.running = true
            } else if (root.phase === "mapped" && Date.now() - root.phaseStarted >= 220) {
                root.phase = "verify"
                cursor.running = true
            } else if (root.phase === "closed" && Date.now() - root.phaseStarted >= 400) {
                if (PickerService.visible) { root.fail("Escape did not close the picker"); return }
                root.phase = "verify-closed"
                cursor.running = true
            }
        }
    }
}
