pragma ComponentBehavior: Bound

import QtQuick
import "../../../ui"
import "../../../theme"
import "../../../services"
import "../../../config"

TooltipArea {
    moduleName: "mic"
    id: root
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    normalIconColor: AudioService.micActive ? Theme.ok : Theme.pulsingTextBaseColor
    tooltipSource: root
    tooltip: micTooltip

    Component {
        id: micTooltip
        AudioTooltip { input: true }
    }

    onAlternateClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) AudioService.openMixer()
    }
    onWheel: event => {
        const delta = event.angleDelta.y > 0 ? Config.audioVolumeStep : -Config.audioVolumeStep
        AudioService.setMicVolume(AudioService.micVolume + delta)
    }

    Row {
        BarIcon {
            color: root.moduleIconColor
            animationEnabled: MotionPolicy.micPulseEnabled
            pulsing: !root.pinned && AudioService.micMutePulse
            baseColor: AudioService.micActive ? Theme.ok : Theme.pulsingTextBaseColor
            text: AudioService.micMuted ? Theme.micMutedIcon : Theme.micIcon
        }
    }
}
