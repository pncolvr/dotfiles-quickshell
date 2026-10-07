import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

UI.TooltipArea {
    id: root
    required property var window
    readonly property bool tooltipKeyboardFocus: true
    tooltipSource: root
    tooltipScreen: window.screen
    tooltip: Component { RecentFilesTooltip {} }
    onClicked: {
        const pos = root.mapToGlobal(root.width / 2, 0)
        TooltipService.togglePin(pos.x, tooltip, root, centerTooltip, tooltipScreen)
    }
    UI.IconText {
        objectName: "recentFilesBarIcon"
        text: Theme.recentFilesIcon
        color: TooltipService.pinned && TooltipService.source === root ? Theme.accent : Theme.text
    }
}
