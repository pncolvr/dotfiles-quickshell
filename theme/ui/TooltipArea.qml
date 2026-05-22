import QtQuick
import "../../services"
import "./components"

WrapperMouseArea {
    id: root
    hoverEnabled: true
    property Component tooltip: null
    property var tooltipSource: null
    property bool centerTooltip: false

    onEntered: {
        if (!tooltip) return
        const pos = root.mapToGlobal(root.width / 2, 0)
        TooltipService.show(pos.x, tooltip, tooltipSource, centerTooltip)
    }
    onExited: TooltipService.hide()
}