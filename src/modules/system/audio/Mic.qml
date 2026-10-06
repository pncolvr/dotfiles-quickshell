pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme/ui"
import "../../../theme"
import "../../../services"
import "../../../config"

TooltipArea {
    id: root
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    readonly property bool tooltipKeyboardFocus: true
    tooltipSource: root
    tooltip: micTooltip

    Component {
        id: micTooltip
        AudioTooltip { input: true }
    }

    onClicked: (mouse) => {
        switch (mouse.button) {
            case Qt.LeftButton: AudioService.toggleMicMute(); break
            case Qt.RightButton: {
                const pos = root.mapToGlobal(root.width / 2, 0)
                TooltipService.togglePin(pos.x, tooltip, root, centerTooltip, tooltipScreen)
                break
            }
            case Qt.MiddleButton: AudioService.openMixer(); break
        }
    }
    onWheel: event => {
        const delta = event.angleDelta.y > 0 ? Config.audioVolumeStep : -Config.audioVolumeStep
        AudioService.setMicVolume(AudioService.micVolume + delta)
    }

    Row {
        PulseIconText {
            pulsing: AudioService.micMuted
            baseColor: AudioService.micActive ? Theme.ok : Theme.pulsingTextBaseColor
            text: AudioService.micMuted ? Theme.micMutedIcon : Theme.micIcon
        }
    }
}
