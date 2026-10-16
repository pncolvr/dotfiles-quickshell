import QtQuick
import "../../theme"
import "../../services"
import "../../theme/ui"

TooltipArea {
    id: root
    moduleName: "sharing"
    visible: AudioService.screencastActive
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

    BarIcon {
        font.pixelSize: Theme.fontSize
        color: root.moduleIconColor
        animationEnabled: MotionPolicy.screenSharePulseEnabled
        pulsing: !root.pinned
        pulseColor: Theme.screencastPulseColor
        text: Theme.screencastIcon
    }
}
