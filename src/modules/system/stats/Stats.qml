import QtQuick
import "../../../theme/ui" as UI
import "../../../theme"
import "../../../services"
import ".."

UI.TooltipArea {
    id: root
    acceptedButtons: Qt.LeftButton
    readonly property bool tooltipKeyboardFocus: true
    tooltipSource: root
    tooltip: Component { StatsTooltip {} }
    onClicked: mouse => {
        if (mouse.button !== Qt.LeftButton) return
        const pos = root.mapToGlobal(root.width / 2, 0)
        TooltipService.togglePin(pos.x, tooltip, root, centerTooltip, tooltipScreen)
    }
    UI.IconText {
        objectName: "statsBarIcon"
        text: Theme.statsIcon
        color: TooltipService.pinned && TooltipService.source === root ? Theme.accent : Theme.text
    }
}
