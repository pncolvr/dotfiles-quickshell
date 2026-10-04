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
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            const pos = root.mapToGlobal(root.width / 2, 0)
            TooltipService.togglePin(pos.x, tooltip, root, centerTooltip, tooltipScreen)
        } else {
            TwitchService.openPicker()
        }
    }
    UI.IconText {
        text: Theme.twitchIcon
        color: TwitchService.hasOnline ? Theme.twitchColor : Theme.inactive
    }
}
