pragma ComponentBehavior: Bound

import "../../../i18n"
import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../../theme"
import "../../../ui" as UI
import "../../../services"
import "../../../config"

Column {
    id: root
    readonly property bool footerInGutter: true
    property bool input: false
    property var audioService: AudioService
    property var mediaService: MediaService
    property alias currentIndex: tabs.currentIndex
    readonly property var devices: input ? audioService.inputDevices : audioService.outputDevices
    readonly property var apps: input ? audioService.micApps : audioService.playbackApps
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxPanelHeight: !input && tabs.currentIndex === 2
        ? Math.max(0,(monitor?.height ?? 1080) - Theme.barHeight - Theme.tooltipPaddingHeight - Theme.tooltipPaddingWidth
            - (Theme.tooltipShadowEnabled ? Math.max(2,Math.min(64,Theme.tooltipShadowBlurRadius)) + Math.max(0,Theme.tooltipShadowVerticalOffset) : 0))
        : (monitor?.height ?? 1080) * Theme.audioTooltipMaxHeightRatio
    readonly property real listHeight: Math.max(0, maxPanelHeight - header.height - spacing
        - footer.height - spacing)
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
            labels: root.input ? [Translations.text("audio.tabs.apps"), Translations.text("audio.tabs.microphones")] : [Translations.text("audio.tabs.apps"), Translations.text("audio.tabs.outputs"), Translations.text("audio.tabs.media")]
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
                text: Translations.text(root.audioService.micActivityEnabled ? "audio.mic.activityEnabled" : "audio.mic.activityDisabled")
            }
        }
        UI.ActionButton {
            id: mute
            objectName: "audioPanelMute"
            keyAction: "audio.mute"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool muted: root.input ? root.audioService.micMuted : root.audioService.muted
            glyph: root.input ? (muted ? Theme.micMutedIcon : Theme.micIcon)
                : (muted ? Theme.volumeMutedIcon : Theme.volumeIcons[Theme.volumeIcons.length - 1])
            foreground: muted ? Theme.warning : Theme.text
            hint: Translations.text(muted ? "audio.actions.unmuteDevice" : "audio.actions.muteDevice",[Translations.text(root.input ? "audio.device.microphone" : "audio.device.audio")])
            enabled: !root.audioService.muteBusy
            onClicked: root.input ? root.audioService.toggleMicMute() : root.audioService.toggleMute()
        }
    }

    MediaPanel {
        objectName: "audioMediaPanel"
        width: root.width + Theme.scrollbarGutter
        maximumHeight: root.listHeight
        mediaService: root.mediaService
        audioService: root.audioService
        visible: !root.input && tabs.currentIndex === 2
    }

    Flickable {
        id: deviceList
        property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: deviceList }
        objectName: "audioDeviceList"
        visible: tabs.currentIndex === 1
        width: root.width + Theme.scrollbarGutter
        height: Math.min(contentHeight, root.listHeight)
        contentWidth: width
        contentHeight: deviceContents.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: deviceContents
            width: root.width
            spacing: Theme.audioSpacing

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
            UI.EmptyState {
                visible: root.devices.length === 0
                text: Translations.text(root.input ? "audio.empty.microphones" : "audio.empty.outputs")
            }
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
    }

    Flickable {
        id: appList
        property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: appList }
        objectName: "audioAppList"
        visible: tabs.currentIndex === 0
        width: root.width + Theme.scrollbarGutter
        height: Math.min(contentHeight, root.listHeight)
        contentWidth: width
        contentHeight: appContents.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: appContents
            width: root.width
            spacing: Theme.audioSpacing

            UI.EmptyState {
                objectName: "audioAppsTitle"
                visible: root.apps.length === 0
                text: Translations.text(root.input ? "audio.empty.recording" : "audio.empty.playback")
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
    UI.PanelFooter {
        id: footer
        objectName: "audioFooter"
        width: root.width
        message: root.audioService.routingBusy ? Translations.text("audio.routing.busy")
            : root.audioService.muteError || root.audioService.routingError || root.audioService.routingMessage
                || (tabs.currentIndex === 1 ? root.audioService.devicesError : "")
        messageColor: root.audioService.muteError || root.audioService.routingError || (tabs.currentIndex === 1 && root.audioService.devicesError) ? Theme.warning : Theme.inactive
    }
}
