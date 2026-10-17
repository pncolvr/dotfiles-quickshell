pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../../src/services"
import "../../../src/modules/launcher"
import "../../../src/config"
import "../../../src/ui" as UI

Scope {
    id: root
    property int attempts: 0
    property int step: 0
    property bool accepted: false
    property bool focusRoundtrip: false
    readonly property bool helperActive: helperWindow.contentItem.Window.active
    Test.TestEvent { id: events }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const found = root.find(child, name)
            if (found) return found
        }
        return null
    }
    function moveTestPointer(item) {
        const pos = item.mapToGlobal(item.width / 2, item.height / 2)
        Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${Math.round(pos.x)}, y = ${Math.round(pos.y)} })`)
    }
    function fail() {
        console.error("FAIL: native private secret picker", root.step, pickerWindow.windowActive, root.helperActive)
        Qt.quit()
    }
    PickerWindow { id: ordinaryWindow }
    PrivatePickerWindow { id: pickerWindow }
    FloatingWindow {
        id: helperWindow
        visible: false
        title: "Quickshell synthetic focus check"
        implicitWidth: 320
        implicitHeight: 160
        UI.InputField {
            id: helperInput
            readonly property bool moduleFocusSearch: true
            anchors.centerIn: parent
            width: 280
            placeholderText: "Synthetic desktop input"
        }
        Connections {
            target: helperWindow.contentItem.Window.window
            function onFrameSwapped() {
                if (root.step !== 6) return
                helperInput.forceActiveFocus()
                root.moveTestPointer(helperInput)
                Hyprland.dispatch('hl.dsp.focus({ window = "title:^Quickshell synthetic focus check$" })')
                root.step = 7
            }
        }
    }
    Process {
        id: client
        command: ["bash", Quickshell.shellPath("src/services/launcher/secret_prompt.sh"), "--prompt", "Synthetic rbw preview", "--description", "Testing the masked prompt; no vault access"]
        stdout: StdioCollector { id: output; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0 || output.text !== "NATIVE_RBW_SYNTHETIC" || PickerService.visible) {
                root.fail(); return
            }
            root.accepted = false
            helperWindow.visible = false
            root.step = 3
            entryClient.running = true
        }
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: entryClient
        command: ["bash", Quickshell.shellPath("src/services/launcher/launcher.sh"), "--json", Quickshell.shellPath("private-options.json")]
        stdout: StdioCollector { id: entryOutput; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0 || entryOutput.text !== "private-entry\n" || PickerService.visible) {
                root.fail(); return
            }
            root.accepted = false
            root.step = 5
            PickerService.begin(PickerService.Mode.Menu, "Synthetic ordinary picker after private menu")
            PickerService.items = [{id: "0", title: "Test item", result: "test"}]
            PickerService.show()
        }
        // qmllint enable signal-handler-parameters
    }
    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (++root.attempts > 32) { root.fail(); return }
            if (root.step === 5) {
                if (!ordinaryWindow.visible || pickerWindow.visible || PickerService.privateWindow
                    || ordinaryWindow.WlrLayershell.namespace !== Config.pickerNamespace) { root.fail(); return }
                PickerService.close()
                console.log("PASS: native centered masked rbw prompt")
                Qt.quit()
                return
            }
            if (root.step === 0) {
                if (!ordinaryWindow.visible || pickerWindow.visible
                    || ordinaryWindow.WlrLayershell.namespace !== Config.pickerNamespace) { root.fail(); return }
                PickerService.close()
                root.step = 1
                client.running = true
                return
            }
            if (!PickerService.visible || !pickerWindow.visible || root.accepted) return
            if (ordinaryWindow.visible || pickerWindow.WlrLayershell.namespace !== Config.screenShareHiddenNamespace) {
                root.fail(); return
            }
            if (root.step === 3) {
                if (PickerService.mode !== PickerService.Mode.Menu || !PickerService.privateWindow) { root.fail(); return }
                console.log("Native private login picker mapped")
                root.step = 4
                return
            }
            if (root.step === 4) {
                root.accepted = true
                events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
                return
            }
            const input = root.find(pickerWindow.previewItem, "secretInput") as UI.InputField
            const button = root.find(pickerWindow.previewItem, "revealSecret") as UI.ActionButton
            if (!input || !button || pickerWindow.contentX <= 0) { root.fail(); return }
            if (root.step === 6) return
            if (root.step === 7) {
                if (!root.helperActive || pickerWindow.windowActive) return
                events.keyClick(Qt.Key_A, Qt.NoModifier, 0)
                events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                if (helperInput.text !== "a" || !PickerService.visible || input.text !== "NATIVE_RBW_SYNTHETIC") {
                    root.fail(); return
                }
                root.moveTestPointer(pickerWindow.panel.panel)
                root.step = 8
                return
            }
            if (root.step === 8) {
                if (!pickerWindow.windowActive || !input.activeFocus) return
                root.focusRoundtrip = true
                root.step = 2
                console.log("PASS: secret prompt survives desktop focus and keyboard input, then resumes unchanged")
                return
            }
            if (root.step === 1) {
                if (input.echoMode !== TextInput.Password) { root.fail(); return }
                input.text = "NATIVE_RBW_SYNTHETIC"
                events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
                if (input.echoMode !== TextInput.Normal || input.text !== "NATIVE_RBW_SYNTHETIC" || !input.activeFocus) {
                    root.fail(); return
                }
                console.log("Native private secret picker mapped")
                root.step = 2
                return
            }
            if (!root.focusRoundtrip) {
                if (!pickerWindow.windowActive || pickerWindow.WlrLayershell.keyboardFocus !== WlrKeyboardFocus.OnDemand) {
                    root.fail(); return
                }
                root.step = 6
                helperWindow.visible = true
                return
            }
            events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
            if (input.echoMode !== TextInput.Password || input.text !== "NATIVE_RBW_SYNTHETIC") { root.fail(); return }
            root.accepted = true
            events.keyClick(Qt.Key_Enter, Qt.NoModifier, 0)
            if (input.text.length || input.echoMode !== TextInput.Password) root.fail()
        }
    }
    Component.onCompleted: {
        PickerService.begin(PickerService.Mode.Menu, "Synthetic ordinary picker")
        PickerService.items = [{id: "0", title: "Test item", result: "test"}]
        PickerService.show()
    }
}
