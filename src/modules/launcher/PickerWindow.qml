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
    readonly property Item previewItem: contentItem
    readonly property bool gridMode: picker.layout === "grid"
    screen: Quickshell.screens.includes(picker.targetScreen) ? picker.targetScreen : Quickshell.screens[0] ?? null
    visible: picker.visible && !!picker.targetScreen
    contentWidth: Math.min(gridMode ? Theme.pickerWidth * 1.5 : Theme.pickerWidth,
        Math.max(0, (screen?.width || 800) - Theme.tooltipRadius * 2 - Theme.tooltipPaddingWidth * 2))
    contentHeight: Math.min(panel.implicitHeight,
        Math.max(0, (screen?.height || 1080) * 0.75 - shadowBottomPadding))
    contentX: (width - contentWidth) / 2
    backgroundOpacity: Theme.pickerBackgroundOpacity
    WlrLayershell.namespace: Config.pickerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) Qt.callLater(() => { panel.focusSearch(); grab.active = true })
    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: if (root.visible) root.picker.close()
    }
    Connections {
        target: root.picker
        function onVisibleChanged() { if (!root.picker.visible) grab.active = false }
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
