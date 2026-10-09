import QtQuick
import "../../theme/ui" as UI
import "../../theme"
import "../../services"

UI.TooltipArea {
    id: root
    readonly property bool tooltipKeyboardFocus: true
    tooltipSource: root
    visible: TwitchService.available
    tooltip: Component { TwitchTooltip {} }
    acceptedButtons: Qt.LeftButton
    onClicked: {
        const pos = root.mapToGlobal(root.width / 2, 0)
        TooltipService.togglePin(pos.x, tooltip, root, centerTooltip, tooltipScreen)
    }
    Connections {
        target: TwitchService
        function onPanelRequested(targetScreen) {
            if (!root.visible || root.tooltipScreen !== targetScreen) return
            const pos = root.mapToGlobal(root.width / 2, 0)
            TooltipService.openForKeyboard(pos.x, root.tooltip, root, root.centerTooltip, root.tooltipScreen)
        }
    }
    UI.IconText {
        text: Theme.twitchIcon
        color: TooltipService.pinned && TooltipService.source === root ? Theme.accent
            : TwitchService.hasOnline ? Theme.twitchColor : Theme.inactive
    }
}
