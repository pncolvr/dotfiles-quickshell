pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme/ui"
import "../../../theme"
import "../../../services"

TooltipArea {
    id: root
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    tooltip: micTooltip

    Component {
        id: micTooltip
        Column {
            ColumnText {
                text: AudioService.micActivityEnabled ? "mic activity enabled" : "mic activity disabled"
            }
            Repeater {
                model: AudioService.micUsers
                ColumnText {
                    required property string modelData
                    text: modelData
                }
            }
        }
    }

    onClicked: (mouse) => {
        switch (mouse.button) {
            case Qt.LeftButton: AudioService.toggleMicMute(); break
            case Qt.RightButton: AudioService.openMixer(); break
        }
    }

    Row {
        PulseIconText {
            pulsing: AudioService.micMuted
            baseColor: AudioService.micActive ? Theme.ok : Theme.pulsingTextBaseColor
            text: AudioService.micMuted ? Theme.micMutedIcon : Theme.micIcon
        }
    }
}
