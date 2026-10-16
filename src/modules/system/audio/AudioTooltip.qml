pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"
import "../../../config"

Column {
    id: root
    property bool input: false
    property var audioService: AudioService
    property var mediaService: MediaService
    property alias currentIndex: tabs.currentIndex
    readonly property var devices: input ? audioService.inputDevices : audioService.outputDevices
    readonly property var apps: input ? audioService.micApps : audioService.playbackApps
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxPanelHeight: !input && tabs.currentIndex === 2
        ? Math.max(0,(monitor?.height ?? 1080) - Theme.barHeight - Theme.tooltipPaddingHeight * 2
            - (Theme.tooltipShadowEnabled ? Math.max(2,Math.min(64,Theme.tooltipShadowBlurRadius)) + Math.max(0,Theme.tooltipShadowVerticalOffset) : 0))
        : (monitor?.height ?? 1080) * Theme.audioTooltipMaxHeightRatio
    readonly property real listHeight: Math.max(0, maxPanelHeight - header.height - spacing
        - (routingFeedback.visible ? routingFeedback.height + spacing : 0))
    width: Math.min(Theme.audioTooltipWidth, (monitor?.width ?? Theme.audioTooltipWidth + Theme.tooltipPaddingWidth * 2) - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.audioSpacing
    Component.onCompleted: {
        audioService.beginPanel()
        if (!input && Config.mediaPreferPlayingTab && mediaService.playing) tabs.currentIndex = 2
    }
    Component.onDestruction: audioService.endPanel()

    Item {
        id: header
        width: parent.width
        height: Theme.controlHeight

        UI.TabBar {
            id: tabs
            objectName: "audioTabs"
            labels: root.input ? ["Apps", "Microphones"] : ["Apps", "Audio outputs", "Media"]
            anchors.left: parent.left
            anchors.right: root.input ? micActivity.left : mute.left
            anchors.rightMargin: Theme.audioSpacing
            height: parent.height
        }
        UI.IconText {
            id: micActivity
            objectName: "micActivity"
            anchors.right: mute.left
            anchors.rightMargin: Theme.audioSpacing
            anchors.verticalCenter: parent.verticalCenter
            visible: root.input
            text: Theme.audioRecordingIcon
            font.pixelSize: Theme.fontSize
            color: root.audioService.micActivityEnabled ? Theme.ok : Theme.inactive
            UI.HoverTooltip {
                objectName: "micActivityHint"
                text: root.audioService.micActivityEnabled ? "Mic activity enabled" : "Mic activity disabled"
            }
        }
        UI.ActionButton {
            id: mute
            objectName: "audioPanelMute"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool muted: root.input ? root.audioService.micMuted : root.audioService.muted
            glyph: root.input ? (muted ? Theme.micMutedIcon : Theme.micIcon)
                : (muted ? Theme.volumeMutedIcon : Theme.volumeIcons[Theme.volumeIcons.length - 1])
            foreground: muted ? Theme.warning : Theme.text
            hint: (muted ? "Unmute " : "Mute ") + (root.input ? "microphone" : "audio")
            onClicked: root.input ? root.audioService.toggleMicMute() : root.audioService.toggleMute()
        }
    }

    UI.ColumnText {
        id: routingFeedback
        width: parent.width
        visible: text.length > 0
        text: root.audioService.routingBusy ? "Switching audio…" : root.audioService.routingError || root.audioService.routingMessage
        color: root.audioService.routingError ? Theme.warning : Theme.inactive
        wrapMode: Text.Wrap
    }

    MediaPanel {
        objectName: "audioMediaPanel"
        width: parent.width
        maximumHeight: root.listHeight
        mediaService: root.mediaService
        audioService: root.audioService
        visible: !root.input && tabs.currentIndex === 2
    }

    Flickable {
        id: deviceList
        objectName: "audioDeviceList"
        visible: tabs.currentIndex === 1
        width: parent.width
        height: Math.min(contentHeight, root.listHeight)
        contentWidth: width
        contentHeight: deviceContents.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: deviceContents
            width: deviceList.width
            spacing: Theme.audioSpacing

            UI.ColumnText {
                width: parent.width
                visible: root.audioService.devicesError.length > 0
                text: root.audioService.devicesError
                color: Theme.warning
                wrapMode: Text.Wrap
            }
            Repeater {
                objectName: "audioDevices"
                model: root.devices
                AudioDeviceRow {
                    required property var modelData
                    node: modelData
                    input: root.input
                    audioService: root.audioService
                    width: deviceContents.width
                }
            }
            UI.ColumnText {
                width: parent.width
                visible: root.devices.length === 0
                text: root.input ? "No microphones available" : "No audio outputs available"
                color: Theme.inactive
                wrapMode: Text.Wrap
            }
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
    }

    Flickable {
        id: appList
        objectName: "audioAppList"
        visible: tabs.currentIndex === 0
        width: parent.width
        height: Math.min(contentHeight, root.listHeight)
        contentWidth: width
        contentHeight: appContents.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: appContents
            width: appList.width
            spacing: Theme.audioSpacing

            UI.ColumnText {
                objectName: "audioAppsTitle"
                width: parent.width
                visible: root.apps.length === 0
                text: root.input ? "No apps recording" : "No apps playing audio"
                color: Theme.inactive
                elide: Text.ElideRight
            }
            Repeater {
                objectName: "audioProcesses"
                model: root.apps
                AudioAppRow {
                    required property var modelData
                    width: appContents.width
                    app: modelData
                    input: root.input
                    audioService: root.audioService
                }
            }
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
    }
}
