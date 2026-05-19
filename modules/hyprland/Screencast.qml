import QtQuick
import "../../theme"
import "../../services"
import "../../theme/ui"

TooltipArea {
    visible: AudioService.screencastActive
    cursorShape: Qt.ArrowCursor
    tooltip: screencastTooltip

    Component {
        id: screencastTooltip
        ColumnText {
            text: "Screenshare active"
        }
    }

    PulseIconText {
        pulsing: true
        pulseColor: Theme.screencastPulseColor
        text: Theme.screencastIcon
    }
}
