pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import "../../services"
Item {
    id: root
    required property var host
    property var picker: PickerService
    readonly property var panel: panelLoader.item
    property bool restoringDialogFocus: false
    function updateFocus() {
        if (!root.host.visible) { restoringDialogFocus = false; grab.active = false; return }
        if (panel?.nativeDialogOpen) { restoringDialogFocus = true; grab.active = false; return }
        Qt.callLater(() => {
            if (!root.host.visible || !panel || panel.nativeDialogOpen) return
            panel.focusSearch()
            if (!root.restoringDialogFocus || root.host.contentItem.Window.active) {
                root.restoringDialogFocus = false
                grab.active = true
            }
        })
    }
    Connections { target: root.host; function onVisibleChanged() { root.updateFocus() } }
    readonly property bool windowActive: host.contentItem.Window.active
    onWindowActiveChanged: if (windowActive && restoringDialogFocus && !panel?.nativeDialogOpen) updateFocus()
    HyprlandFocusGrab {
        id: grab
        windows: [root.host]
        onCleared: if (root.host.visible && !root.panel?.nativeDialogOpen && !root.restoringDialogFocus) root.picker.close()
    }
    Connections {
        target: root.panel
        function onNativeDialogOpenChanged() { root.updateFocus() }
    }
    Component.onCompleted: ClipboardService.initialize()

    Loader {
        id: panelLoader
        active: root.enabled
        width: root.host.contentWidth
        height: root.host.contentHeight
        sourceComponent: PickerPanel {
            width: root.host.contentWidth
            height: root.host.contentHeight
            backgroundVisible: false
            picker: root.picker
        }
        onLoaded: root.updateFocus()
    }
}
