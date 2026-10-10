pragma ComponentBehavior: Bound

import QtQuick
import "../../../services"
import "../../../theme"
import "../../../theme/ui"
import "../../../config"

TooltipArea {
    moduleName: "volume"
    id: root
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    readonly property bool tooltipKeyboardFocus: true
    tooltipSource: root
    hoverEnabled: true
    tooltip: audioTooltip

    Component {
        id: audioTooltip
        AudioTooltip {}
    }

    onClicked: (mouse) => {
        switch (mouse.button) {
            case Qt.LeftButton: AudioService.toggleMute(); break
            case Qt.RightButton: {
                const pos = root.mapToGlobal(root.width / 2, 0)
                TooltipService.togglePin(pos.x, tooltip, root, centerTooltip, tooltipScreen)
                break
            }
            case Qt.MiddleButton: AudioService.openMixer(); break
        }
    }
    onWheel: (event) => {
        if (!AudioService.sink?.audio) return
        const delta = event.angleDelta.y > 0 ? Config.audioVolumeStep : -Config.audioVolumeStep
        AudioService.setVolume(AudioService.volume + delta)
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
