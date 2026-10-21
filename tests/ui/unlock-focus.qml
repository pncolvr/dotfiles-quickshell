pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Wayland
import "../../src/modules/vault"
import "../../src/modules/launcher"
import "../../src/ui" as UI
import "../../src/services"

WorkerScope {
    id: root
    property int stage: -1
    property int attempts: 0
    property bool accepted: false
    property bool cancelled: false
    readonly property UI.InputField search: manager.panel
        ? objects.findChild(manager.panel, "vaultSearch") as UI.InputField : null
    function finish() { PickerService.close(); RbwService.close(); Qt.quit() }
    function fail(message) { console.error("UNLOCK FOCUS FAIL:", message); finish() }
    Test.TestCase { id: events; when: false }
    Test.TestResult { id: objects }
    VaultWindow { id: manager }
    PrivatePickerWindow { id: prompt }
    Timer {
        interval: 30
        repeat: true
        running: true
        onTriggered: {
            if (++root.attempts > 100) {
                root.fail("native password or manager search did not regain keyboard focus at stage " + root.stage)
                return
            }
            switch (root.stage) {
            case -1:
                // Exercise the real manager without calling open(), starting an
                // rbw worker, reading a vault, or touching the clipboard.
                RbwService.busy = true
                RbwService.targetScreen = Quickshell.screens[0]
                RbwService.visible = true
                root.stage = 0
                break
            case 0:
                if (!root.search?.activeFocus || !manager.contentItem.Window.active) return
                root.search.text = "Synthetic query"
                root.stage = 1
                PickerService.promptSecret("Synthetic unlock focus check", "Test only — no vault access", null,
                    value => root.accepted = value === "x")
                break
            case 1: {
                const field = objects.findChild(prompt.panel, "secretInput") as UI.SecretField
                if (!field?.activeFocus || !prompt.windowActive) return
                events.keyClick(Qt.Key_X)
                if (field.text.length !== 1 || manager.WlrLayershell.keyboardFocus !== WlrKeyboardFocus.None) {
                    root.fail("password typing or parent handoff")
                    return
                }
                events.keyClick(Qt.Key_Return)
                root.stage = 2
                break
            }
            case 2:
                if (prompt.visible || !root.search?.activeFocus || !manager.contentItem.Window.active) return
                if (!root.accepted || root.search.text !== "Synthetic query") {
                    root.fail("accepting the password changed the manager query")
                    return
                }
                root.search.cursorPosition = root.search.text.length
                events.keyClick(Qt.Key_Z)
                if (root.search.text !== "Synthetic queryz") {
                    root.fail("typing after unlock did not reach Search")
                    return
                }
                // A completed worker reply must not be necessary to type again.
                RbwService.busy = false
                root.stage = 3
                break
            case 3:
                RbwService.busy = true
                root.stage = 4
                PickerService.promptSecret("Synthetic cancellation check", "Test only — no vault access", null,
                    value => root.cancelled = value === null)
                break
            case 4: {
                const field = objects.findChild(prompt.panel, "secretInput") as UI.SecretField
                if (!field?.activeFocus || !prompt.windowActive) return
                events.keyClick(Qt.Key_Escape)
                root.stage = 5
                break
            }
            case 5:
                if (prompt.visible || !root.search?.activeFocus || !manager.contentItem.Window.active) return
                if (!root.cancelled || root.search.text !== "Synthetic queryz") {
                    root.fail("cancelling unlock changed the manager query")
                    return
                }
                console.log("PASS: native unlock focuses the password, returns keyboard typing to vault Search after acceptance or cancellation, and preserves the query")
                root.stage = 6
                root.finish()
                break
            }
        }
    }
}
