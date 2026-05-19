pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme/ui"
import "../../../theme"
import "../../../services"

TooltipArea {
    id: root
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    tooltip: AudioService.micUsers.length > 0 ? micTooltip : null

    Component {
        id: micTooltip
        Column {
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
            text: AudioService.micMuted ? Theme.micMutedIcon : Theme.micIcon
        }
    }
}
