pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Row {
    id: root
    required property var app
    property bool input: false
    property var audioService: AudioService
    readonly property bool muted: audioService.appMuted(app)
    readonly property bool canMute: app.nodes.every(node => node.ready && !!node.audio)
    readonly property var devices: (input ? audioService.inputs : audioService.outputs)
        .filter(node => node.ready).slice().sort((a, b) => audioService.deviceName(a).localeCompare(audioService.deviceName(b)))
    spacing: Theme.audioSpacing

    UI.ColumnText {
        objectName: "audioAppName"
        width: root.width - selector.width - muteButton.width - root.spacing * 2
        height: Theme.audioButtonHeight
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
        text: root.app.name
        elide: Text.ElideRight
        UI.HoverTooltip { text: root.app.name }
    }

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

    AudioSelector {
        id: selector
        objectName: "appDeviceSelector"
        width: Math.min(Theme.audioAppSelectorWidth, root.width * 0.65)
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
