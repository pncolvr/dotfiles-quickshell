import QtQuick
import Quickshell.Wayland
import "../theme"
import "../services"

TopPanelTooltip {
    id: root
    readonly property bool onTooltipScreen: !TooltipService.screen || TooltipService.screen === screen
    readonly property bool shouldShow: TooltipService.visible && onTooltipScreen && !TooltipService.ownsTooltipWindow
    visible: shouldShow
    WlrLayershell.keyboardFocus: TooltipService.source?.tooltipKeyboardFocus
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    contentWidth: loader.implicitWidth + Theme.tooltipPaddingWidth * 2
    contentHeight: loader.implicitHeight + Theme.tooltipPaddingHeight * 2
    contentX: {
        const ideal = TooltipService.centered
            ? (width - contentWidth) / 2
            : TooltipService.x - (screen?.x ?? 0) - contentWidth / 2
        return Math.max(0, Math.min(width - contentWidth, ideal))
    }

    Loader {
        id: loader
        active: root.shouldShow
        anchors.centerIn: parent
        sourceComponent: TooltipService.content
    }

    HoverHandler {
        onPointChanged: if (hovered) {
            const pos = parent.mapToGlobal(point.position.x, point.position.y)
            TooltipService.observePointer(pos.x, pos.y, true)
        }
        onHoveredChanged: if (root.visible) TooltipService.setPanelHovered(hovered)
    }
}
