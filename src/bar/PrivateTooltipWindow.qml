import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config"
import "../services"

TopPanelTooltip {
    id: root
    readonly property var targetScreen: Quickshell.screens.includes(TooltipService.screen)
        ? TooltipService.screen : Quickshell.screens[0] ?? null
    screen: targetScreen
    visible: false
    contentX: {
        const ideal = TooltipService.centered ? (width - contentWidth) / 2
            : TooltipService.x - (screen?.x ?? 0) - contentWidth / 2
        return Math.max(0, Math.min(width - contentWidth, ideal))
    }
    WlrLayershell.namespace: Config.screenShareHiddenNamespace
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    TooltipPointerHandler { tooltipWindow: root }

    HoverHandler {
        onPointChanged: if (hovered) {
            const pos = parent.mapToGlobal(point.position.x, point.position.y)
            TooltipService.observePointer(pos.x, pos.y, true)
        }
        onHoveredChanged: if (root.visible) TooltipService.setPanelHovered(hovered)
    }
}
