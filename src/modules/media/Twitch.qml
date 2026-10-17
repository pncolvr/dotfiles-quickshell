import QtQuick
import "../../theme/ui" as UI
import "../../theme"
import "../../services"

UI.TooltipArea {
    id: root
    moduleName: "twitch"

    normalIconColor: TwitchService.hasOnline ? Theme.twitchColor : Theme.text
    tooltipSource: root
    visible: TwitchService.available
    tooltip: Component { TwitchTooltip {} }
    acceptedButtons: Qt.LeftButton

    UI.BarIcon {
        text: Theme.twitchIcon
        color: root.moduleIconColor
    }
}
