pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../bar"
import "../../services"
import "../../theme"
PrivateTopPanelTooltip {
    id: root
    screen: Quickshell.screens.includes(RbwService.targetScreen) ? RbwService.targetScreen : Quickshell.screens[0] ?? null
    readonly property VaultPanel panel: loader.item as VaultPanel
    visible: RbwService.visible && !!screen
    contentWidth: Math.min(780, Math.max(0, (geometryScreen?.width ?? 800) - Theme.tooltipPaddingWidth * 2))
    contentHeight: Math.min(760, Math.max(0, (geometryScreen?.height ?? 1080) * 0.8 - shadowBottomPadding))
    contentX: (width - contentWidth) / 2
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: PickerService.visible ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    Loader {
        id: loader
        active: root.visible
        width: root.contentWidth
        height: root.contentHeight
        sourceComponent: VaultPanel {}
        onLoaded: Qt.callLater(() => root.panel?.focusSearch())
    }
    Connections { target: PickerService; function onVisibleChanged() { if (!PickerService.visible && root.visible) Qt.callLater(() => root.panel?.focusSearch()) } }
}
