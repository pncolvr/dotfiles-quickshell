pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../bar"
import "../../theme"
import "../../services"

PrivateTopPanelTooltip {
    id: root
    property var picker: PickerService
    readonly property var panel: behavior.panel
    readonly property bool restoringDialogFocus: behavior.restoringDialogFocus
    readonly property bool windowActive: contentItem.Window.active
    readonly property Item previewItem: contentItem
    screen: Quickshell.screens.includes(picker.targetScreen) ? picker.targetScreen : Quickshell.screens[0] ?? null
    visible: picker.visible && picker.layout !== "expose" && !!picker.targetScreen
        && picker.privateWindow
    contentWidth: behavior.boundedContentWidth
    contentHeight: behavior.boundedContentHeight
    implicitHeight: behavior.reservedHostHeight
    contentX: behavior.centeredContentX
    backgroundOpacity: Theme.pickerBackgroundOpacity

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: panel?.nativeDialogOpen ? WlrKeyboardFocus.None
        : behavior.secretPrompt ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.Exclusive

    PickerWindowContent { id: behavior; host: root; picker: root.picker; enabled: root.picker.privateWindow; anchors.fill: parent }
}
