pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../bar"
import "../../theme"
import "../../services"
import "../../config"

TopPanelTooltip {
    id: root
    property var picker: PickerService
    readonly property var panel: behavior.panel
    readonly property bool restoringDialogFocus: behavior.restoringDialogFocus
    readonly property bool windowActive: contentItem.Window.active
    readonly property Item previewItem: contentItem
    screen: Quickshell.screens.includes(picker.targetScreen) ? picker.targetScreen : Quickshell.screens[0] ?? null
    visible: picker.visible && picker.layout !== "expose" && !!picker.targetScreen
        && !picker.privateWindow
    contentWidth: Math.min(Theme.pickerWidth,
        Math.max(0, (geometryScreen?.width || 800) - Theme.tooltipRadius * 2 - Theme.tooltipPaddingWidth * 2))
    contentHeight: Math.min(panel?.implicitHeight ?? 0,
        Math.max(0, (geometryScreen?.height || 1080) * 0.75 - shadowBottomPadding))
    contentX: (width - contentWidth) / 2
    backgroundOpacity: Theme.pickerBackgroundOpacity
    WlrLayershell.namespace: Config.pickerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: panel?.nativeDialogOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    PickerWindowContent { id: behavior; host: root; picker: root.picker; enabled: !root.picker.privateWindow; anchors.fill: parent }
}
