pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../src/services"
import "../../../src/modules/launcher"
import "../../../src/config"
import "../../../src/theme/ui" as UI

Scope {
    id: root
    property int attempts: 0
    property int step: 0
    property bool accepted: false
    Test.TestEvent { id: events }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const found = root.find(child, name)
            if (found) return found
        }
        return null
    }
    function fail() { console.error("FAIL: native private secret picker"); Qt.quit() }
    PickerWindow { id: ordinaryWindow }
    PrivatePickerWindow { id: pickerWindow }
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
            if (++root.attempts > 16) { root.fail(); return }
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
