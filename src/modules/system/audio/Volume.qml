pragma ComponentBehavior: Bound

import QtQuick
import "../../../services"
import "../../../theme"
import "../../../theme/ui"
import "../../../config"

TooltipArea {
    moduleName: "volume"
    id: root
    readonly property var mediaService: MediaService
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    tooltipSource: root
    hoverEnabled: true
    tooltip: audioTooltip

    Component {
        id: audioTooltip
        AudioTooltip { mediaService: root.mediaService }
    }

    onAlternateClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) AudioService.openMixer()
    }
    onWheel: (event) => {
        if (!AudioService.sink?.audio) return
        const delta = event.angleDelta.y > 0 ? Config.audioVolumeStep : -Config.audioVolumeStep
        AudioService.setVolume(AudioService.volume + delta)
    }

    Row {
        BarIcon {
            font.pixelSize: Theme.fontSize
            color: root.moduleIconColor
            animationEnabled: MotionPolicy.volumePulseEnabled
            pulsing: !root.pinned && AudioService.outputMutePulse
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
