import QtQuick
import "../theme"
import "../services"

TopPanelTooltip {
    id: root
    visible: TooltipService.visible

    contentWidth: loader.implicitWidth + Theme.tooltipPaddingWidth * 2
    contentHeight: loader.implicitHeight + Theme.tooltipPaddingHeight * 2
    contentX: {
        const ideal = TooltipService.x - contentWidth / 2
        return Math.max(0, Math.min(width - contentWidth, ideal))
    }

    Loader {
        id: loader
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
