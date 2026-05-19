pragma ComponentBehavior: Bound

import QtQuick
import "../../../services"
import "../../../theme"
import "../../../theme/ui"

TooltipArea {
    id: root
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    tooltip: AudioService.audioUsers.length > 0 ? audioTooltip : null

    Component {
        id: audioTooltip
        Column {
            Repeater {
                model: AudioService.audioUsers
                ColumnText {
                    required property string modelData
                    text: modelData
                }
            }
        }
    }

    onClicked: (mouse) => {
        switch (mouse.button) {
            case Qt.LeftButton: AudioService.toggleMute(); break
            case Qt.RightButton: AudioService.openMixer(); break
        }
    }
    onWheel: (event) => {
        if (!AudioService.sink?.audio) return
        const delta = event.angleDelta.y > 0 ? 0.01 : -0.01
        AudioService.setVolume(Math.max(0, Math.min(1, AudioService.volume + delta)))
    }

    Row {
        PulseIconText {
            pulsing: AudioService.muted
            text: root.volumeIcon()
        }

        Text {
            visible: root.containsMouse
            text: `${Math.round((AudioService.volume ?? 0) * 100)}%`
        }
    }

    function volumeIcon() {
        if (AudioService.muted || AudioService.volume === 0) return Theme.volumeMutedIcon
        const i = Math.min(Theme.volumeIcons.length - 1, Math.floor(AudioService.volume * Theme.volumeIcons.length))
        return Theme.volumeIcons[i]
    }
}
