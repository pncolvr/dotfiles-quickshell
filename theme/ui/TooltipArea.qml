import QtQuick
import Quickshell
import "../../services"
import "./components"

WrapperMouseArea {
    id: root
    hoverEnabled: true
    property Component tooltip: null
    property var tooltipSource: null
    property bool centerTooltip: false
    readonly property var tooltipWindow: root.QsWindow.window
    property var tooltipScreen: tooltipWindow?.screen

    onEntered: {
        if (!tooltip) return
        const pos = root.mapToGlobal(root.width / 2, 0)
        TooltipService.show(pos.x, tooltip, tooltipSource, centerTooltip, tooltipScreen)
    }
    onExited: TooltipService.hide()
}
