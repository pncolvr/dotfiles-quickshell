pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../../src/services"
import "../../../src/modules/launcher"
import "../../../src/ui" as UI

Scope {
    id: root
    Test.TestResult { id: objects }
    Test.TestEvent { id: events }
    FloatingWindow {
        visible: true
        implicitWidth: 560
        implicitHeight: 500
        PickerPanel { id: panel; anchors.fill: parent }
    }
    function field() { return objects.findChild(panel.panel, "secretInput") }
    IpcHandler {
        target: "rbwtest"
        function snapshot(): string {
            const input = root.field()
            return JSON.stringify({visible: PickerService.visible, secret: PickerService.mode === PickerService.Mode.Secret,
                masked: input?.echoMode === TextInput.Password, textLength: input?.text.length || 0,
                revealed: panel.panel?.secretRevealed ?? false,
                valueIntact: input?.text === Quickshell.env("RBW_TEST_SECRET"),
                privateWindow: PickerService.privateWindow,
                query: PickerService.query, forcePrompt: PickerService.forcePrompt, prompt: PickerService.prompt,
                preferences: PickerService.selectionKey, directory: PickerService.requestDirectory})
        }
        function typeSecret(): void { root.field().text = Quickshell.env("RBW_TEST_SECRET") }
        function toggleEye(): void {
            const button = objects.findChild(panel.panel, "revealSecret") as UI.ActionButton
            events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
        function submit(): void {
            const input = root.field()
            if (input) {
                input.text = Quickshell.env("RBW_TEST_SECRET")
                input.forceActiveFocus()
                events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
            } else PickerService.accept(false, false)
        }
        function cancel(): void {
            const input = root.field()
            if (input) {
                input.forceActiveFocus()
                events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
            } else PickerService.close()
        }
    }
    Component.onCompleted: console.log("RBW test shell ready")
}
