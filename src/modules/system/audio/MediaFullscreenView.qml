pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Rectangle {
    id: root
    required property var player
    property var audioService: AudioService
    property var mediaService: MediaService
    property bool monitorPosition: false
    readonly property var app: mediaService.appForPlayer(player, audioService.playbackApps)
    readonly property bool muted: app ? audioService.appMuted(app) : false
    readonly property real volume: app ? audioService.appVolume(app) : 0
    readonly property string appIcon: DesktopEntries.byId(player?.desktopEntry || "")?.icon || ""
    readonly property bool hasDuration: !!player?.lengthSupported && Number.isFinite(player.length)
        && player.length > 0 && player.length * 1000000 <= Number.MAX_SAFE_INTEGER
    readonly property bool hasPosition: !!player?.positionSupported && hasDuration
    readonly property bool canSeek: hasPosition && !!player?.canSeek
    readonly property real horizontalMargin: width * 0.02
    readonly property real verticalMargin: height * 0.02
    readonly property real cacheScale: Math.min(1, Theme.mediaFullscreenCacheWidth / Math.max(1, width),
        Theme.mediaFullscreenCacheHeight / Math.max(1, height))
    readonly property int cacheWidth: Math.max(1, Math.round(width * cacheScale))
    readonly property int cacheHeight: Math.max(1, Math.round(height * cacheScale))
    readonly property real artworkSize: Math.max(1, volumeControls.visible
        ? volumeControls.width : Math.min(360, width * 0.25))
    color: Qt.alpha(Theme.alternateBackground, 1)
    function timeText(seconds) {
        seconds = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(seconds / 60);
        return (minutes >= 60 ? Math.floor(minutes / 60) + ":" + String(minutes % 60).padStart(2, "0") : String(minutes))
            + ":" + String(seconds % 60).padStart(2, "0");
    }
    function seekTo(seconds) {
        if (canSeek && Number.isFinite(seconds)) tracker.seekTo(Math.max(0, Math.min(player.length, seconds)));
    }
    MediaCardBackground {
        id: backgroundSource
        width: root.cacheWidth
        height: root.cacheHeight
        radius: 0
        artworkSource: root.player?.trackArtUrl || ""
        onReadyChanged: backgroundTexture.scheduleUpdate()
    }
    UI.ScaledTexture {
        id: backgroundTexture
        objectName: "mediaFullscreenBackgroundTexture"
        anchors.fill: parent
        sourceItem: backgroundSource.ready ? backgroundSource : null
        textureSize: Qt.size(root.cacheWidth, root.cacheHeight)
        hideSource: true
        live: false
        mipmap: false
    }
    MediaVisualizer {
        id: visualizer
        objectName: "mediaVisualizer"
        anchors.fill: parent
        opacity: Theme.mediaVisualizerFrontOpacity
        appId: MediaService.normalized(String(root.player?.desktopEntry || root.player?.identity || "").trim())
        nodes: root.app?.nodes ?? []
        playing: !!root.player?.isPlaying
        active: !!root.app && !root.muted && root.monitorPosition && root.visible
            && root.opacity > 0 && (root.Window.window?.visible ?? false)
    }
    onPlayerChanged: if (visualizer) visualizer.clear()
    Connections { target: root.player; function onTrackChanged() { visualizer.clear(); } }
    MediaPosition {
        id: tracker
        objectName: "mediaPositionTracker"
        player: root.player
        mediaService: root.mediaService
        active: root.monitorPosition && root.hasPosition && root.visible
    }
    MediaEffectList {
        id: effects
        objectName: "mediaEffectSelector"
        anchors.left: parent.left
        anchors.leftMargin: root.horizontalMargin
        anchors.bottom: controls.top
        anchors.bottomMargin: Theme.audioSpacing * 2
        width: Math.min(250, root.width * 0.2)
        height: Math.min(Theme.mediaFullscreenEffectListHeight, root.height * 0.65)
        options: visualizer.effects
        selectedName: visualizer.effect
        enabled: root.monitorPosition && !!root.app
    }
    Connections { target: effects; function onSelected(name) { visualizer.selectEffect(name); } }
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: root.horizontalMargin
        anchors.bottom: controls.top
        anchors.bottomMargin: Theme.audioSpacing * 2
        width: root.artworkSize
        height: width
        color: artwork.status === Image.Ready ? "transparent" : Theme.background
        radius: Theme.audioDeviceRadius
        UI.CroppedImage {
            id: artwork
            objectName: "mediaArtwork"
            anchors.fill: parent
            source: root.player?.trackArtUrl || ""
            asynchronous: true
        }
        UI.ScaledImage {
            id: appArtwork
            anchors.centerIn: parent
            width: root.artworkSize * 0.18
            height: width
            source: root.appIcon ? Quickshell.iconPath(root.appIcon, true) : ""
            visible: artwork.status !== Image.Ready
        }
        UI.IconText {
            anchors.centerIn: parent
            text: Theme.mediaIcon
            font.pixelSize: root.artworkSize * 0.18
            color: Theme.accent
            visible: artwork.status !== Image.Ready && appArtwork.status !== Image.Ready
        }
    }
    Column {
        anchors.centerIn: parent
        width: Math.max(1, root.width - 2 * (effects.x + effects.width + root.horizontalMargin))
        spacing: Theme.audioSpacing * 2
        UI.ColumnText {
            objectName: "mediaTitle"
            width: parent.width
            font.pixelSize: Theme.fontSize * 4
            horizontalAlignment: Text.AlignHCenter
            text: root.player?.trackTitle || root.player?.identity || Translations.text("media.player.fallbackName")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
        UI.ColumnText {
            objectName: "mediaDetails"
            width: parent.width
            font.pixelSize: Theme.fontSize * 2.5
            horizontalAlignment: Text.AlignHCenter
            text: root.player?.trackArtist || ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            visible: !!text
        }
        UI.ColumnText {
            objectName: "mediaApp"
            width: parent.width
            font.pixelSize: Theme.fontSize * 1.75
            horizontalAlignment: Text.AlignHCenter
            text: root.player?.identity || Translations.text("media.player.fallbackName")
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }
        UI.ColumnText {
            objectName: "mediaVisualizerStatus"
            width: parent.width
            color: Theme.inactive
            horizontalAlignment: Text.AlignHCenter
            text: visualizer.error ? Translations.text("media.visualizer.unavailable")
                : !root.app ? ""
                : !root.player?.isPlaying ? Translations.text("media.states.paused") : root.muted ? Translations.text("audio.states.muted") : ""
            visible: !!text
        }
    }
    RowLayout {
        id: controls
        objectName: "mediaPlaybackRow"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.horizontalMargin
        anchors.rightMargin: root.horizontalMargin
        anchors.bottomMargin: root.verticalMargin
        spacing: playbackControls.spacing
        Row {
            id: playbackControls
            objectName: "mediaPlaybackControls"
            readonly property real buttonSize: Math.max(1, Math.min(Theme.audioButtonHeight * 1.6,
                (effects.width - Theme.audioSpacing * 3) / 4))
            Layout.preferredWidth: effects.width
            Layout.minimumWidth: effects.width
            Layout.maximumWidth: effects.width
            spacing: Math.max(0, (effects.width - buttonSize * 4) / 3)
            AudioButton {
                objectName: "mediaPrevious"
                glyph: Theme.mediaPreviousIcon
                glyphSize: Theme.fontSize * 1.6
                width: playbackControls.buttonSize
                height: width
                hint: Translations.text("media.actions.previousTrack")
                enabled: !!root.player?.canGoPrevious
                onClicked: root.player.previous()
            }
            AudioButton {
                objectName: "mediaPlayPause"
                glyph: root.player?.isPlaying ? Theme.pauseIcon : Theme.playIcon
                glyphSize: Theme.fontSize * 1.6
                width: playbackControls.buttonSize
                height: width
                hint: Translations.text(root.player?.isPlaying ? "media.actions.pause" : "media.actions.play")
                highlightedDevice: true
                enabled: root.player?.isPlaying ? !!root.player?.canPause : !!root.player?.canPlay
                onClicked: { if (root.player.isPlaying) root.player.pause(); else root.player.play(); }
            }
            AudioButton {
                objectName: "mediaNext"
                glyph: Theme.mediaNextIcon
                glyphSize: Theme.fontSize * 1.6
                width: playbackControls.buttonSize
                height: width
                hint: Translations.text("media.actions.nextTrack")
                enabled: !!root.player?.canGoNext
                onClicked: root.player.next()
            }
            AudioButton {
                objectName: "mediaStop"
                glyph: Theme.mediaStopIcon
                glyphSize: Theme.fontSize * 1.6
                width: playbackControls.buttonSize
                height: width
                hint: Translations.text("media.actions.stop")
                enabled: !!root.player?.canControl
                onClicked: root.player.stop()
            }
        }
        UI.ColumnText {
            objectName: "mediaElapsed"
            font.pixelSize: Theme.fontSize * 1.3
            visible: root.hasPosition
            text: root.timeText(timeline.pressed ? timeline.value : tracker.position)
        }
        AudioVolumeSlider {
            id: timeline
            objectName: "mediaTimeline"
            Layout.fillWidth: true
            leftPadding: 0
            rightPadding: 0
            visible: root.hasPosition
            enabled: root.canSeek
            volume: tracker.position
            to: root.hasDuration ? root.player.length : 1
            stepSize: 1
            wheelEnabled: false
            Accessible.name: Translations.text("media.position.accessibleName")
            onVolumeMoved: value => root.seekTo(value)
        }
        Item { visible: !root.hasPosition; Layout.fillWidth: true }
        UI.ColumnText {
            objectName: "mediaDuration"
            font.pixelSize: Theme.fontSize * 1.3
            visible: root.hasPosition
            text: root.timeText(root.player?.length || 0)
        }
        RowLayout {
            id: volumeControls
            objectName: "mediaVolumeControls"
            visible: !!root.app
            spacing: controls.spacing
            AudioButton {
                objectName: "mediaMute"
                glyph: root.muted ? Theme.volumeMutedIcon : Theme.volumeIcons[Theme.volumeIcons.length - 1]
                glyphSize: Theme.fontSize * 1.5
                Layout.preferredWidth: playbackControls.buttonSize
                Layout.preferredHeight: playbackControls.buttonSize
                hint: Translations.text(root.muted ? "audio.actions.unmute" : "audio.actions.mute")
                highlightedDevice: root.muted
                onClicked: if (root.app) root.audioService.toggleAppMute(root.app, false)
            }
            AudioVolumeSlider {
                objectName: "mediaVolume"
                Layout.preferredWidth: Math.min(260, root.width * 0.16)
                leftPadding: 0
                rightPadding: 0
                volume: root.volume
                muted: root.muted
                Accessible.name: Translations.text("media.volume.accessibleName")
                onVolumeMoved: value => { if (root.app) root.audioService.setAppVolume(root.app, value); }
            }
            UI.ColumnText {
                id: volumePercentage
                objectName: "mediaVolumeValue"
                font.pixelSize: Theme.fontSize * 1.3
                Layout.preferredWidth: Math.ceil(percentageMetrics.advanceWidth)
                Layout.minimumWidth: Layout.preferredWidth
                Layout.maximumWidth: Layout.preferredWidth
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.volume * 100) + "%"
            }
            TextMetrics {
                id: percentageMetrics
                font: volumePercentage.font
                text: "100%"
            }
        }
    }
}
