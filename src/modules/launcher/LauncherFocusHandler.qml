pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import "../../services"

// Ordinary/private pickers and the overview share activation, dialog recovery,
// outside-click dismissal and the optional pointer move after a rendered frame.
Item {
    id: root
    required property var host
    property var panel: null
    property var picker: PickerService
    property bool ready: true
    readonly property bool secretPrompt: picker.mode === PickerService.Mode.Secret
    readonly property bool movePointer: picker.mode !== PickerService.Mode.Clipboard && picker.movePointer !== false
    readonly property var nativeWindow: host.contentItem.Window.window
    readonly property bool windowActive: host.contentItem.Window.active
    property bool pointerPending: false
    property bool restoringDialogFocus: false
    function requestFocus() {
        if (!host.visible || !ready) { pointerPending = false; restoringDialogFocus = false; grab.active = false; return }
        if (panel?.nativeDialogOpen) { restoringDialogFocus = true; grab.active = false; return }
        if (secretPrompt) grab.active = false
        Qt.callLater(() => {
            if (!root.host.visible || !root.ready || !root.panel || root.panel.nativeDialogOpen) return
            root.panel.focusSearch()
            root.pointerPending = root.movePointer
            root.nativeWindow?.update()
            // Grabbing before the compositor activates the layer can prevent
            // keyboard focus when the pointer stays outside its input region.
            if (!root.secretPrompt && root.windowActive) {
                root.restoringDialogFocus = false
                grab.active = true
            }
        })
    }
    onPanelChanged: requestFocus()
    onReadyChanged: requestFocus()
    onWindowActiveChanged: if (windowActive && ready && !panel?.nativeDialogOpen) {
        if (restoringDialogFocus) requestFocus()
        else if (!secretPrompt && host.visible) grab.active = true
    }
    Connections { target: root.host; function onVisibleChanged() { root.requestFocus() } }
    Connections { target: root.picker; function onOpened() { root.requestFocus() } }
    Connections {
        target: root.panel
        ignoreUnknownSignals: true // Overview panels have no native file dialog.
        function onNativeDialogOpenChanged() { root.requestFocus() }
    }
    Connections {
        target: root.nativeWindow
        function onFrameSwapped() {
            if (!root.pointerPending) return
            root.pointerPending = false
            if (root.host.visible && root.ready && root.movePointer && !root.panel?.nativeDialogOpen)
                BarModuleService.movePointer(root.panel)
        }
    }
    HyprlandFocusGrab {
        id: grab
        windows: [root.host]
        onCleared: if (root.host.visible && root.ready && !root.secretPrompt
            && !root.panel?.nativeDialogOpen && !root.restoringDialogFocus) root.picker.close()
    }
}
