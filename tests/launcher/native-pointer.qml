pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/launcher"

Scope {
    id: root
    readonly property var scenarios: ["list", "input", "image", "clipboard", "clipboard-images", "passive", "private-passive", "list"]
    property int scenario: 0
    readonly property string kind: scenarios[scenario] ?? ""
    readonly property bool keepPointer: kind.startsWith("clipboard") || kind.endsWith("passive")
    readonly property var currentWindow: PickerService.privateWindow ? privateWindow : window
    property string phase: "open"
    property double phaseStarted: 0
    property var savedPosition: null
    property bool failed: false
    Test.TestEvent { id: events }
    PickerWindow { id: window }
    PrivatePickerWindow { id: privateWindow }
    function fail(message) {
        failed = true
        console.error("POINTER FAIL:", kind, phase, message)
        PickerService.close()
        Qt.quit()
    }
    function openCurrent() {
        PickerService.begin(kind.startsWith("clipboard") ? PickerService.Mode.Clipboard : PickerService.Mode.Menu,"Synthetic pointer check")
        PickerService.movePointer = !kind.endsWith("passive")
        PickerService.privateRequest = kind === "private-passive"
        if (kind === "clipboard-images") PickerService.itemCriteria = {kind:"image"}
        PickerService.allowTyped = kind === "input"
        PickerService.imageOnly = kind === "image"
        PickerService.items = kind === "input" ? [] : [{id:"0",title:"Synthetic item",result:"test",
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
            if (!root.currentWindow.windowActive) {
                if (Date.now() - root.phaseStarted > 2000) { root.fail("launcher has no native keyboard focus"); return }
                root.phase = "mapped"
                return
            }
            const target = root.currentWindow.panel.modulePointerTarget
            const topLeft = target.mapToGlobal(0,0)
            if (root.keepPointer) {
                if (point.x !== root.savedPosition.x || point.y !== root.savedPosition.y) { root.fail("pointer moved in a context-preserving picker"); return }
            } else if (point.x < topLeft.x || point.x >= topLeft.x + target.width
                || point.y < topLeft.y || point.y >= topLeft.y + target.height) { root.fail("pointer did not enter the launcher target"); return }
            if (root.kind !== "image") {
                events.keyClick(Qt.Key_A, Qt.NoModifier, 0)
                if (PickerService.query !== "a") { root.fail("keyboard search is unavailable"); return }
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
                if (root.keepPointer) {
                    const target = window.panel.modulePointerTarget
                    const point = target.mapToGlobal(target.width / 2,target.height + 300)
                    root.phase = "place"
                    placeCursor.command = ["hyprctl","dispatch",`hl.dsp.cursor.move({ x = ${Math.round(point.x)}, y = ${Math.round(point.y)} })`]
                    placeCursor.running = true
                } else root.openCurrent()
            } else if (root.phase === "mapped" && Date.now() - root.phaseStarted >= 220) {
                root.phase = "verify"
                cursor.running = true
            } else if (root.phase === "closed") {
                if (PickerService.visible) { root.fail("Escape did not close the picker"); return }
                if (++root.scenario === root.scenarios.length) {
                    console.log("PASS: native launcher pointer placement, stationary clipboard/capture/private menus, keyboard search and Escape")
                    Qt.quit()
                } else root.phase = "open"
            }
        }
    }
}
