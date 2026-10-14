import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

PrivateTopPanelTooltip {
    id: root
    readonly property var targetScreen: Quickshell.screens.includes(TooltipService.screen)
        ? TooltipService.screen : Quickshell.screens[0] ?? null
    screen: targetScreen
    visible: false
    contentX: {
        const ideal = TooltipService.centered ? (width - contentWidth) / 2
            : TooltipService.x - (geometryScreen?.x ?? 0) - contentWidth / 2
        return Math.max(0, Math.min(width - contentWidth, ideal))
    }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    TooltipPointerHandler { objectName: "tooltipPointerHandler"; tooltipWindow: root }
}
