import QtQuick
import "../../theme/ui" as UI
import "../../theme"
import "../../services"

UI.TooltipArea {
    visible: TwitchService.available
    tooltip: Component { TwitchTooltip {} }
    onClicked: TwitchService.openPicker()
    UI.IconText {
        text: Theme.twitchIcon
        color: TwitchService.hasOnline ? Theme.twitchColor : Theme.inactive
    }
}