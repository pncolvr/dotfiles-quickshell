pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"
import "../../../config"

Rectangle {
    id: root
    required property var player
    property var audioService: AudioService
    property var mediaService: MediaService
    property bool monitorPosition: true
    readonly property bool hasPosition: !!player?.positionSupported
    // MPRIS lengths are microseconds; live players can report an int64 maximum sentinel.
    readonly property bool hasDuration: !!player?.lengthSupported && Number.isFinite(player.length)
        && player.length > 0 && player.length * 1000000 <= Number.MAX_SAFE_INTEGER
    readonly property bool canSeek: !!player?.canSeek && hasPosition && hasDuration
    readonly property real position: playbackPosition.position
    function timeText(seconds) {
        seconds = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(seconds / 60);
        return (minutes >= 60 ? Math.floor(minutes / 60) + ":" + String(minutes % 60).padStart(2, "0") : String(minutes)) + ":" + String(seconds % 60).padStart(2, "0");
    }
    function seekTo(seconds) {
        if (canSeek && Number.isFinite(seconds))
            playbackPosition.seekTo(Math.max(0, Math.min(player.length, seconds)));
    }
    readonly property var app: mediaService.appForPlayer(player, audioService.playbackApps)
    readonly property bool canVolume: !!app || mediaService.volumeSupported(player)
    readonly property real volume: app ? audioService.appVolume(app) : player?.volume ?? 0
    readonly property bool muted: app ? audioService.appMuted(app) : volume === 0
    readonly property string appIcon: DesktopEntries.byId(player?.desktopEntry || "")?.icon || ""
    readonly property real artworkSize: playbackControls.implicitWidth
    readonly property real readoutWidth: Math.max(duration.implicitWidth, volumeValue.implicitWidth)
    implicitHeight: contents.implicitHeight + Theme.audioDevicePadding * 2
    color: Theme.alternateBackground
    radius: Theme.audioDeviceRadius
    border.width: 1
    border.color: Theme.empty
    Item {
        anchors.fill: parent
        anchors.margins: root.border.width
        visible: backgroundArtwork.status === Image.Ready
        UI.ScaledImage {
            id: backgroundArtwork
            anchors.fill: parent
            source: artwork.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
            visible: false
        }
        Rectangle {
            id: backgroundMask
            anchors.fill: parent
            radius: Math.max(0, root.radius - root.border.width)
            color: "white"
            visible: false
        }
        UI.ScaledTexture {
            id: backgroundMaskTexture
            sourceItem: backgroundMask
            hideSource: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: backgroundArtwork
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: Theme.mediaArtworkBlurRadius
            blur: 1
            colorization: Theme.mediaArtworkBackgroundTint
            colorizationColor: Theme.alternateBackground
            opacity: Theme.mediaArtworkBackgroundOpacity
            maskEnabled: true
            maskSource: backgroundMaskTexture
        }
    }
    MediaPosition {
        id: playbackPosition
        objectName: "mediaPositionTracker"
        player: root.player
        mediaService: root.mediaService
        active: root.visible && (root.Window.window?.visible ?? false) && root.monitorPosition && root.hasDuration
    }
    Column {
        id: contents
        x: Theme.audioDevicePadding
        y: Theme.audioDevicePadding
        width: root.width - Theme.audioDevicePadding * 2
        spacing: Theme.audioSpacing
        RowLayout {
            width: parent.width
            spacing: Theme.audioSpacing
            Rectangle {
                Layout.preferredWidth: root.artworkSize
                Layout.preferredHeight: root.artworkSize
                color: Theme.background
                radius: Theme.audioDeviceRadius
                UI.ScaledImage {
                    id: artwork
                    objectName: "mediaArtwork"
                    anchors.fill: parent
                    source: root.visible ? root.player?.trackArtUrl || "" : ""
                    asynchronous: true
                    sourceSize.width: width * Screen.devicePixelRatio
                    sourceSize.height: height * Screen.devicePixelRatio
                }
                UI.ScaledImage {
                    id: appArtwork
                    anchors.centerIn: parent
                    width: Theme.mediaFallbackIconSize
                    height: width
                    source: root.appIcon ? Quickshell.iconPath(root.appIcon, true) : ""
                    visible: artwork.status !== Image.Ready
                }
                UI.IconText {
                    anchors.centerIn: parent
                    text: Theme.mediaIcon
                    font.pixelSize: Theme.mediaFallbackIconSize
                    color: Theme.accent
                    visible: artwork.status !== Image.Ready && appArtwork.status !== Image.Ready
                }
            }

            Item {
                id: information
                readonly property real detailsTop: (height - details.implicitHeight - Theme.audioSpacing - volumeRow.implicitHeight) / 2
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(root.artworkSize, details.implicitHeight + Theme.audioSpacing + volumeRow.implicitHeight)
                Column {
                    id: details
                    width: parent.width
                    y: Math.max(0, information.detailsTop - Theme.audioSpacing)
                    spacing: Theme.audioSpacing
                    UI.ColumnText {
                        objectName: "mediaTitle"
                        color: Theme.text
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.player?.trackTitle || root.player?.identity || "Media player"
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    UI.ColumnText {
                        objectName: "mediaDetails"
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.player?.trackArtist || ""
                        textFormat: Text.PlainText
                        color: Theme.text
                        visible: !!text
                        elide: Text.ElideRight
                    }
                }
                RowLayout {
                    id: volumeRow
                    width: parent.width
                    y: Math.max(information.detailsTop + details.height + Theme.audioSpacing,
                        (information.detailsTop + details.height + parent.height - height) / 2)
                    spacing: Theme.audioSpacing
                    AudioButton {
                        objectName: "mediaMute"
                        glyph: root.muted ? Theme.volumeMutedIcon : Theme.volumeIcons[Theme.volumeIcons.length - 1]
                        hint: root.muted ? "Unmute" : "Mute"
                        enabled: root.canVolume
                        highlightedDevice: root.muted
                        onClicked: {
                            if (root.app)
                                root.audioService.toggleAppMute(root.app, false);
                            else
                                root.mediaService.toggleMute(root.player);
                        }
                    }
                    AudioVolumeSlider {
                        objectName: "mediaVolume"
                        Layout.fillWidth: true
                        volume: root.volume
                        muted: root.muted
                        to: root.app ? Config.audioMaxVolume : 1
                        enabled: root.canVolume
                        Accessible.name: "Media volume"
                        onVolumeMoved: value => {
                            if (root.app)
                                root.audioService.setAppVolume(root.app, value);
                            else
                                root.player.volume = value;
                        }
                    }
                    UI.ColumnText {
                        id: volumeValue
                        Layout.preferredWidth: root.readoutWidth
                        horizontalAlignment: Text.AlignRight
                        text: root.canVolume ? Math.round(root.volume * 100) + "%" : "Unavailable"
                        color: Theme.text
                    }
                }
            }
        }
        RowLayout {
            objectName: "mediaPlaybackRow"
            width: parent.width
            spacing: Theme.audioSpacing
            Row {
                id: playbackControls
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.audioSpacing
                AudioButton {
                    objectName: "mediaPrevious"
                    glyph: Theme.mediaPreviousIcon
                    hint: "Previous"
                    enabled: !!root.player?.canGoPrevious
                    onClicked: root.player.previous()
                }
                AudioButton {
                    objectName: "mediaPlayPause"
                    glyph: root.player?.isPlaying ? Theme.pauseIcon : Theme.playIcon
                    hint: root.player?.isPlaying ? "Pause" : "Play"
                    highlightedDevice: true
                    enabled: root.player?.isPlaying ? !!root.player?.canPause : !!root.player?.canPlay
                    onClicked: {
                        if (root.player.isPlaying)
                            root.player.pause();
                        else
                            root.player.play();
                    }
                }
                AudioButton {
                    objectName: "mediaNext"
                    glyph: Theme.mediaNextIcon
                    hint: "Next"
                    enabled: !!root.player?.canGoNext
                    onClicked: root.player.next()
                }
                AudioButton {
                    objectName: "mediaStop"
                    glyph: Theme.mediaStopIcon
                    hint: "Stop playback"
                    enabled: !!root.player?.canControl
                    onClicked: root.player.stop()
                }
            }
            UI.ColumnText {
                objectName: "mediaElapsed"
                visible: root.hasPosition && root.hasDuration
                text: root.hasDuration ? root.timeText(timeline.pressed ? timeline.value : root.position) : "--:--"
                color: Theme.text
                Layout.alignment: Qt.AlignVCenter
            }
            AudioVolumeSlider {
                id: timeline
                objectName: "mediaTimeline"
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: root.hasPosition && root.hasDuration
                volume: root.hasDuration ? root.position : 0
                to: root.hasDuration ? root.player.length : 1
                stepSize: 1
                wheelEnabled: false
                enabled: root.canSeek
                Accessible.name: "Playback position"
                onVolumeMoved: value => root.seekTo(value)
            }
            UI.ColumnText {
                id: duration
                Layout.preferredWidth: root.readoutWidth
                horizontalAlignment: Text.AlignRight
                objectName: "mediaDuration"
                visible: root.hasPosition && root.hasDuration
                text: root.hasDuration ? root.timeText(root.player.length) : "--:--"
                color: Theme.text
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                visible: !root.hasPosition || !root.hasDuration
                Layout.fillWidth: true
            }
        }
    }
}
