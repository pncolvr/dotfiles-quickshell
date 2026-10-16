pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../bar"
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"

TopPanelTooltip {
    id: root
    UI.CaptureOverlay { host: root; requested: root.requestedVisible }
    property var picker: PickerService
    readonly property var panel: behavior.panel
    readonly property bool restoringDialogFocus: behavior.restoringDialogFocus
    readonly property bool windowActive: contentItem.Window.active
    readonly property Item previewItem: contentItem
    requestedScreen: Quickshell.screens.includes(picker.targetScreen) ? picker.targetScreen : Quickshell.screens[0] ?? null
    requestedVisible: picker.visible && picker.layout !== "expose" && !!picker.targetScreen
        && !picker.privateWindow
    contentWidth: behavior.boundedContentWidth
    contentHeight: behavior.boundedContentHeight
    continuousGeometry: panel?.transitioning ?? false
    reservedContentHeight: behavior.reservedHostHeight - shadowBottomPadding
    contentX: behavior.centeredContentX
    backgroundOpacity: Theme.pickerBackgroundOpacity
    WlrLayershell.namespace: Config.pickerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: behavior.keyboardFocusMode

    PickerWindowContent { id: behavior; host: root; picker: root.picker; enabled: !root.picker.privateWindow; anchors.fill: parent }
}
