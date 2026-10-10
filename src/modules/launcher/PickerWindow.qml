pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../bar"
import "../../theme"
import "../../services"
import "../../config"

TopPanelTooltip {
    id: root
    property var picker: PickerService
    property bool restoringDialogFocus: false
    readonly property bool windowActive: contentItem.Window.active
    readonly property Item previewItem: contentItem
    screen: Quickshell.screens.includes(picker.targetScreen) ? picker.targetScreen : Quickshell.screens[0] ?? null
    visible: picker.visible && picker.layout !== "expose" && !!picker.targetScreen
    contentWidth: Math.min(Theme.pickerWidth,
        Math.max(0, (screen?.width || 800) - Theme.tooltipRadius * 2 - Theme.tooltipPaddingWidth * 2))
    contentHeight: Math.min(panel.implicitHeight,
        Math.max(0, (screen?.height || 1080) * 0.75 - shadowBottomPadding))
    contentX: (width - contentWidth) / 2
    backgroundOpacity: Theme.pickerBackgroundOpacity
    WlrLayershell.namespace: Config.pickerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: panel.nativeDialogOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    function updateFocus() {
        if (!visible) { restoringDialogFocus = false; grab.active = false; return }
        if (panel.nativeDialogOpen) { restoringDialogFocus = true; grab.active = false; return }
        Qt.callLater(() => {
            if (!root.visible || panel.nativeDialogOpen) return
            panel.focusSearch()
            if (!root.restoringDialogFocus || root.windowActive) {
                root.restoringDialogFocus = false
                grab.active = true
            }
        })
    }
    onVisibleChanged: updateFocus()
    onWindowActiveChanged: if (windowActive && restoringDialogFocus && !panel.nativeDialogOpen) updateFocus()
    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: if (root.visible && !panel.nativeDialogOpen && !root.restoringDialogFocus) root.picker.close()
    }
    Connections {
        target: panel
        function onNativeDialogOpenChanged() { root.updateFocus() }
    }
    Component.onCompleted: ClipboardService.initialize()

    PickerPanel {
        id: panel
        width: root.contentWidth
        height: root.contentHeight
        backgroundVisible: false
        picker: root.picker
    }
}
