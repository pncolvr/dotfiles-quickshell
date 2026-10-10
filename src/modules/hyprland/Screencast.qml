import QtQuick
import "../../theme"
import "../../services"
import "../../theme/ui"

TooltipArea {
    moduleName: "sharing"
    visible: AudioService.screencastActive
    cursorShape: Qt.ArrowCursor
    tooltip: screencastTooltip

    Component {
        id: screencastTooltip
        Column {
            width: Theme.screencastTooltipWidth
            spacing: Theme.controlSpacing
            ColumnText { text: "Screen sharing"; color: Theme.accent }
            Repeater {
                model: AudioService.screencastStreams
                delegate: ColumnText {
                    required property var modelData
                    width: parent.width
                    text: modelData.description
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    color: Theme.inactive
                }
            }
        }
    }

    PulseIconText {
        pulsing: true
        pulseColor: Theme.screencastPulseColor
        text: Theme.screencastIcon
    }
}
