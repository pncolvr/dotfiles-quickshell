pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Rectangle {
    id: root
    required property var app
    property bool input: false
    property var audioService: AudioService
    readonly property real volume: audioService.appVolume(app)
    readonly property bool muted: audioService.appMuted(app)
    readonly property bool canMute: app.nodes.every(node => node.ready && !!node.audio)
    readonly property var devices: (input ? audioService.inputs : audioService.outputs)
        .filter(node => node.ready).slice().sort((a, b) => audioService.deviceName(a).localeCompare(audioService.deviceName(b)))
    readonly property int padding: Theme.audioDevicePadding
    implicitHeight: contents.implicitHeight + padding * 2
    radius: Theme.audioDeviceRadius
    color: Theme.alternateBackground
    border.width: 1
    border.color: Theme.empty

    Column {
        id: contents
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: Theme.audioSpacing

        UI.ColumnText {
            objectName: "audioAppName"
            width: contents.width
            textFormat: Text.PlainText
            text: root.app.name
            elide: Text.ElideRight
            UI.HoverTooltip { text: root.app.name }
        }

        Row {
            width: contents.width
            spacing: contents.spacing

            AudioButton {
                id: muteButton
                objectName: "appMute"
                glyph: root.input
                    ? (root.muted ? Theme.micMutedIcon : Theme.micIcon)
                    : (root.muted ? Theme.volumeMutedIcon : Theme.volumeIcons[Theme.volumeIcons.length - 1])
                hint: (root.muted ? "Unmute " : "Mute ") + root.app.name
                enabled: root.canMute
                highlightedDevice: root.muted
                onClicked: root.audioService.toggleAppMute(root.app, root.input)
            }

            AudioVolumeSlider {
                id: slider
                objectName: "appVolume"
                width: Math.max(0, (Math.min(Theme.audioAppSelectorWidth, contents.width * 0.65)
                    - Theme.audioPercentageWidth - contents.spacing) / 2)
                volume: root.volume
                muted: root.muted
                enabled: root.canMute && root.app.nodes.length > 0
                Accessible.name: (root.input ? "Microphone gain: " : "Volume: ") + root.app.name
                onVolumeMoved: value => root.audioService.setAppVolume(root.app, value)
            }

            UI.Text {
                id: percentage
                objectName: "appVolumePercentage"
                width: Theme.audioPercentageWidth
                height: Theme.audioButtonHeight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: `${Math.round(root.volume * 100)}%`
                color: root.muted ? Theme.inactive : Theme.text
            }

            AudioSelector {
                objectName: "appDeviceSelector"
                width: contents.width - muteButton.width - slider.width - percentage.width - contents.spacing * 3
                compact: true
                options: root.devices.map(node => ({name: node.name, description: root.audioService.deviceName(node), available: true}))
                selectedName: root.app.deviceName
                placeholder: root.app.multipleDevices ? "Multiple devices" : "Choose device"
                hint: !root.app.routable ? "Device selection is unavailable for this app"
                    : (root.input ? "Microphone for " : "Output for ") + root.app.name
                enabled: root.app.routable && options.length > 0 && !root.audioService.routingBusy
                onSelected: name => {
                    const device = root.devices.find(node => node.name === name)
                    if (device) root.audioService.moveApp(root.app, device, root.input)
                }
            }
        }
    }
}
