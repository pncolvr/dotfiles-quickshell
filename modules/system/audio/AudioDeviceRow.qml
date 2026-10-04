pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"
import "../../../config"

Rectangle {
    id: root
    required property var node
    property bool input: false
    property var audioService: AudioService
    readonly property bool isDefault: audioService.isDefault(node, input)
    readonly property bool deviceReady: node?.ready && !!node?.audio
    readonly property bool muted: node?.audio?.muted ?? false
    readonly property var card: audioService.cardForNode(node)
    implicitHeight: contents.implicitHeight + Theme.audioDevicePadding * 2
    radius: Theme.audioDeviceRadius
    color: Theme.alternateBackground
    border.width: 1
    border.color: isDefault ? Theme.accent : Theme.empty

    Column {
        id: contents
        x: Theme.audioDevicePadding
        y: Theme.audioDevicePadding
        width: root.width - Theme.audioDevicePadding * 2
        spacing: Theme.audioSpacing

        UI.ColumnText {
            objectName: "deviceName"
            width: parent.width
            text: root.audioService.deviceName(root.node)
            wrapMode: Text.Wrap
        }

        Row {
            visible: !!root.node?.audio
            width: parent.width
            spacing: Theme.audioSpacing

            AudioButton {
                id: muteButton
                objectName: "deviceMute"
                glyph: root.input
                    ? (root.muted ? Theme.micMutedIcon : Theme.micIcon)
                    : (root.muted ? Theme.volumeMutedIcon : Theme.volumeIcons[Theme.volumeIcons.length - 1])
                hint: (root.muted ? "Unmute " : "Mute ") + root.audioService.deviceName(root.node)
                enabled: root.deviceReady
                highlightedDevice: root.muted
                onClicked: root.audioService.toggleNodeMute(root.node)
            }

            QC.Slider {
                id: slider
                objectName: "deviceVolume"
                width: parent.width - muteButton.width - Theme.audioPercentageWidth - Theme.audioSpacing * 2
                height: Theme.audioButtonHeight
                from: 0
                to: Config.audioMaxVolume
                stepSize: Config.audioVolumeStep
                wheelEnabled: true
                enabled: root.deviceReady
                Accessible.name: (root.input ? "Microphone gain: " : "Volume: ") + root.audioService.deviceName(root.node)
                onMoved: root.audioService.setNodeVolume(root.node, value)
                HoverHandler {
                    enabled: slider.enabled
                    cursorShape: Qt.PointingHandCursor
                }
                Binding {
                    target: slider
                    property: "value"
                    value: root.node?.audio?.volume ?? 0
                    when: !slider.pressed
                    restoreMode: Binding.RestoreBindingOrValue
                }
                background: Rectangle {
                    x: slider.leftPadding
                    y: (slider.height - height) / 2
                    width: slider.availableWidth
                    height: Theme.audioSliderTrackHeight
                    radius: height / 2
                    color: Theme.empty
                    Rectangle {
                        width: slider.visualPosition * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: root.muted ? Theme.inactive : Theme.accent
                    }
                }
                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: (slider.height - height) / 2
                    width: Theme.audioSliderHandleSize
                    height: width
                    radius: width / 2
                    color: slider.pressed || slider.activeFocus ? Theme.accent : Theme.text
                    border.color: Theme.accent
                    border.width: slider.activeFocus ? 2 : 0
                }
            }

            UI.Text {
                width: Theme.audioPercentageWidth
                height: Theme.audioButtonHeight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: `${Math.round((root.node?.audio?.volume ?? 0) * 100)}%`
                color: root.muted ? Theme.inactive : Theme.text
            }
        }

        Row {
            visible: !!root.node?.audio
            spacing: Theme.audioSpacing
            AudioButton {
                objectName: "deviceUseNow"
                glyph: Theme.audioUseNowIcon
                label: "Use now"
                hint: root.input ? "Move current recording apps here" : "Move current playback apps here"
                enabled: root.deviceReady && !root.audioService.routingBusy
                onClicked: root.audioService.useNow(root.node, root.input)
            }
            AudioButton {
                objectName: "deviceDefault"
                glyph: Theme.audioDefaultIcon
                label: root.isDefault ? "Default" : "Set default"
                hint: root.isDefault ? "System default" : (root.input ? "Set as the system default microphone" : "Set as the system default output")
                highlightedDevice: root.isDefault
                enabled: root.deviceReady && !root.isDefault
                onClicked: root.audioService.setDefault(root.node, root.input)
            }
            UI.Text {
                text: [root.audioService.deviceInUse(root.node, root.input) ? "In use" : "", root.muted ? "Muted" : ""].filter(Boolean).join(" · ")
                color: Theme.inactive
            }
        }

        AudioProfileSelector {
            objectName: "deviceProfile"
            width: parent.width
            visible: !!root.card
            card: root.card
            audioService: root.audioService
        }
    }
}
