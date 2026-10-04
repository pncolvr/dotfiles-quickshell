import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

TopPanelTooltip {
    id: root
    readonly property bool onTooltipScreen: !TooltipService.screen || TooltipService.screen === screen
    readonly property bool shouldShow: TooltipService.visible && onTooltipScreen && !TooltipService.notificationPanel
    visible: shouldShow
    WlrLayershell.keyboardFocus: TooltipService.source?.tooltipKeyboardFocus
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Transparent space beside a tooltip should pass pointer events through.
    mask: Region { x: root.contentX; width: root.contentWidth; height: root.contentHeight }

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
        onHoveredChanged: {
            if (hovered) TooltipService.cancelHide()
            else TooltipService.hide()
        }
    }
}
