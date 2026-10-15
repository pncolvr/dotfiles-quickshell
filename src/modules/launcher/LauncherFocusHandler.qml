pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import "../../services"

// Ordinary/private pickers and the overview share activation, dialog recovery,
// outside-click dismissal. Keyboard activation never changes pointer position.
Item {
    id: root
    required property var host
    property var panel: null
    property var picker: PickerService
    property bool ready: true
    readonly property bool secretPrompt: picker.mode === PickerService.Mode.Secret
    readonly property bool windowActive: host.contentItem.Window.active
    property bool requestingKeyboardFocus: false
    property bool restoringDialogFocus: false
    function requestFocus() {
        if (!host.visible || !ready) { requestingKeyboardFocus = false; restoringDialogFocus = false; grab.active = false; return }
        if (panel?.nativeDialogOpen) { requestingKeyboardFocus = false; restoringDialogFocus = true; grab.active = false; return }
        requestingKeyboardFocus = !windowActive
        if (secretPrompt) grab.active = false
        Qt.callLater(() => {
            if (!root.host.visible || !root.ready || !root.panel || root.panel.nativeDialogOpen) return
            root.panel.focusSearch()
            // Grabbing before the compositor activates the layer can prevent
            // keyboard focus when the pointer stays outside its input region.
            if (root.windowActive) {
                root.restoringDialogFocus = false
                grab.active = true
            }
        })
    }
    onPanelChanged: requestFocus()
    onReadyChanged: requestFocus()
    onWindowActiveChanged: {
        // Secret prompts stay open when the user activates another window.
        if (!windowActive) {
            if (secretPrompt) { requestingKeyboardFocus = false; grab.active = false }
            return
        }
        if (!ready || panel?.nativeDialogOpen) return
        Qt.callLater(() => { if (root.windowActive) root.requestingKeyboardFocus = false })
        if (restoringDialogFocus) requestFocus()
        else if (host.visible) grab.active = true
    }
    Connections { target: root.host; function onVisibleChanged() { root.requestFocus() } }
    Connections { target: root.picker; function onOpened() { root.requestFocus() } }
    Connections {
        target: root.panel
        ignoreUnknownSignals: true // Overview panels have no native file dialog.
        function onNativeDialogOpenChanged() { root.requestFocus() }
    }
    HyprlandFocusGrab {
        id: grab
        windows: [root.host]
        onCleared: if (root.host.visible && root.ready && !root.secretPrompt
            && !root.panel?.nativeDialogOpen && !root.restoringDialogFocus) root.picker.close()
    }
}
