pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"
import "../../../config"

Item {
    id: root
    required property var player
    property var audioService: AudioService
    property var mediaService: MediaService
    property bool monitorPosition: true
    property bool preparingFullscreen: false
    readonly property real cardInset: 1
    readonly property real overlayRadius: Math.max(0, Theme.audioDeviceRadius - 1)
    readonly property bool processingAllowed: monitorPosition && !MediaFullscreenService.visible
    readonly property bool animationsEnabled: Config.animateDuringScreenShare || !AudioService.screencastActive
    property bool flipped: false
    readonly property bool flipping: flipAnimation.running
    readonly property bool showingBack: Math.abs(flipRotation.angle) > 90
    onAnimationsEnabledChanged: {
        if (!animationsEnabled && flipping) flipAnimation.complete();
    }
    onFlippedChanged: {
        flipAnimation.stop();
        if (animationsEnabled) {
            flipAnimation.to = flipped ? -180 : 0;
            flipAnimation.restart();
        } else flipRotation.angle = flipped ? -180 : 0;
    }
    Component.onCompleted: {
        flipAnimation.stop();
        flipRotation.angle = flipped ? -180 : 0;
    }
    onPlayerChanged: {
        if (visualizer) visualizer.clear();
    }
    function toggleFullscreen() {
        if (flipping || preparingFullscreen) return;
        const screen = (root.QsWindow.window as QsWindow)?.screen ?? TooltipService.screen;
        const origin = mapToGlobal(0, 0);
        const sourceRect = Qt.rect(origin.x, origin.y, width, height);
        const open = snapshot => {
            preparingFullscreen = false;
            MediaFullscreenService.open(player, audioService, mediaService, flipped, screen, sourceRect, snapshot);
            TooltipService.dismiss();
        };
        if (!animationsEnabled || Theme.mediaFullscreenAnimationDuration <= 0) {
            open(null);
            return;
        }
        // Keep a single frozen frame so the zoom starts with the exact compact card.
        preparingFullscreen = true;
        if (!grabToImage(open)) open(null);
    }
    function flip() {
        if (flipping) return;
        flipped = !flipped;
    }
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
    onAppChanged: if (!app) flipped = false
    readonly property bool canVolume: !!app
    readonly property real volume: app ? audioService.appVolume(app) : 0
    readonly property bool muted: app ? audioService.appMuted(app) : false
    readonly property string appIcon: DesktopEntries.byId(player?.desktopEntry || "")?.icon || ""
    readonly property real artworkSize: playbackControls.implicitWidth
    readonly property real readoutWidth: Math.max(duration.implicitWidth, app ? volumeValue.implicitWidth : 0)
    implicitHeight: contents.implicitHeight + Theme.audioDevicePadding * 2
    // Capture and render once; each face displays the shared source beneath its content.
    MediaVisualizer {
        id: visualizer
        objectName: "mediaVisualizer"
        anchors.fill: parent
        anchors.margins: root.cardInset
        appId: MediaService.normalized(String(root.player?.desktopEntry || root.player?.identity || "").trim())
        nodes: root.app?.nodes ?? []
        playing: !!root.player?.isPlaying
        active: !!root.app && !root.muted && !root.flipping && root.visible && root.opacity > 0
            && root.width > 2 && root.height > 2 && root.processingAllowed
            && (root.flipped ? Theme.mediaVisualizerBackOpacity : Theme.mediaVisualizerFrontOpacity) > 0
            && (root.Window.window?.visible ?? false)
    }
    UI.ScaledTexture {
        id: sharedVisualizerTexture
        objectName: "mediaVisualizerTexture"
        sourceItem: visualizer.rendering ? visualizer : null
        live: visualizer.rendering
        hideSource: true
        visible: false
    }
    Connections {
        target: root.player
        function onTrackChanged() { visualizer.clear(); }
    }
    Connections {
        target: MediaFullscreenService
        function onClosed(player, flipped) {
            if (root.player === player) root.flipped = !!root.app && flipped;
        }
    }
    NumberAnimation {
        id: flipAnimation
        target: flipRotation
        property: "angle"
        duration: Theme.mediaFlipDuration
        easing.type: Easing.InOutCubic
    }
    Flipable {
        id: faces
        anchors.fill: parent
        transform: Rotation {
            id: flipRotation
            origin.x: faces.width / 2
            origin.y: faces.height / 2
            axis { x: 0; y: 1; z: 0 }
        }
        front: Rectangle {
            objectName: "mediaFront"
            anchors.fill: parent
            enabled: !root.flipped && !root.flipping
            color: Theme.alternateBackground
            radius: Theme.audioDeviceRadius
            border.width: root.cardInset
            border.color: Theme.empty
            MediaCardBackground {
                anchors.fill: parent
                anchors.margins: root.cardInset
                radius: root.overlayRadius
                visible: !root.showingBack
                artworkSource: artwork.source
            }
            MediaCardVisualizer {
                objectName: "mediaFrontVisualizer"
                anchors.fill: parent
                anchors.margins: root.cardInset
                radius: root.overlayRadius
                z: 1
                textureSource: sharedVisualizerTexture
                active: visualizer.rendering && !root.showingBack
                opacity: Theme.mediaVisualizerFrontOpacity
            }
            MediaPosition {
                id: playbackPosition
                objectName: "mediaPositionTracker"
                player: root.player
                mediaService: root.mediaService
                active: root.visible && (root.Window.window?.visible ?? false) && root.processingAllowed
                    && root.hasDuration && !root.flipped && !root.flipping
            }
            Row {
                id: frontActions
                z: 3
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.audioDevicePadding
                spacing: Theme.audioSpacing
                AudioButton {
                    objectName: "mediaFullscreen"
                    glyph: Theme.mediaExpandIcon
                    hint: "Fullscreen"
                    enabled: !root.flipping && !root.preparingFullscreen
                    onClicked: root.toggleFullscreen()
                }
                AudioButton {
                    objectName: "mediaFlip"
                    glyph: Theme.mediaFlipIcon
                    hint: "Flip to audio visualizer"
                    visible: !!root.app
                    onClicked: root.flip()
                }
            }
            Column {
                id: contents
                z: 2
                x: (root.width - width) / 2
                y: Theme.audioDevicePadding
                width: root.width - Theme.audioDevicePadding * 2
                spacing: Theme.audioSpacing
                RowLayout {
                    width: parent.width
                    spacing: Theme.audioSpacing
                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: root.artworkSize
                        Layout.preferredHeight: root.artworkSize
                        color: artwork.status === Image.Ready ? "transparent" : Theme.background
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
                        readonly property real volumeHeight: volumeRow.visible ? Theme.audioSpacing + volumeRow.implicitHeight : 0
                        readonly property real singleLineTitleSpace: volumeRow.visible && titleText.lineCount === 1
                            ? titleText.implicitHeight : 0
                        readonly property real detailsTop: volumeRow.visible
                            ? height - details.implicitHeight - volumeHeight - singleLineTitleSpace
                            : (height - details.implicitHeight) / 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(root.artworkSize, details.implicitHeight + volumeHeight + singleLineTitleSpace)
                        Column {
                            id: details
                            width: parent.width
                            y: Math.max(0, information.detailsTop)
                            spacing: Theme.audioSpacing / 2
                            UI.ColumnText {
                                id: titleText
                                objectName: "mediaTitle"
                                font.pixelSize: Theme.fontSize
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
                                font.pixelSize: Theme.fontSize
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: root.player?.trackArtist || ""
                                textFormat: Text.PlainText
                                color: Theme.text
                                visible: !!text
                                elide: Text.ElideRight
                            }
                            UI.ColumnText {
                                objectName: "mediaApp"
                                font.pixelSize: Theme.fontSize
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: root.player?.identity || "Media player"
                                textFormat: Text.PlainText
                                color: Theme.text
                                elide: Text.ElideRight
                            }
                        }
                        RowLayout {
                            id: volumeRow
                            visible: !!root.app
                            width: parent.width
                            anchors.bottom: parent.bottom
                            spacing: Theme.audioSpacing
                            AudioButton {
                                objectName: "mediaMute"
                                glyphSize: Theme.fontSize
                                implicitHeight: Theme.audioButtonHeight
                                glyph: root.muted ? Theme.volumeMutedIcon : Theme.volumeIcons[Theme.volumeIcons.length - 1]
                                hint: root.muted ? "Unmute" : "Mute"
                                enabled: root.canVolume
                                highlightedDevice: root.muted
                                onClicked: {
                                    if (root.app) root.audioService.toggleAppMute(root.app, false);
                                }
                            }
                            AudioVolumeSlider {
                                objectName: "mediaVolume"
                                Layout.fillWidth: true
                                volume: root.volume
                                muted: root.muted
                                to: Config.audioMaxVolume
                                enabled: root.canVolume
                                Accessible.name: "Media volume"
                                onVolumeMoved: value => {
                                    if (root.app) root.audioService.setAppVolume(root.app, value);
                                }
                            }
                            UI.ColumnText {
                                id: volumeValue
                                objectName: "mediaVolumeValue"
                                font.pixelSize: Theme.fontSize
                                Layout.preferredWidth: root.readoutWidth
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(root.volume * 100) + "%"
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
                            glyphSize: Theme.fontSize
                            implicitHeight: Theme.audioButtonHeight
                            glyph: Theme.mediaPreviousIcon
                            hint: "Previous"
                            enabled: !!root.player?.canGoPrevious
                            onClicked: root.player.previous()
                        }
                        AudioButton {
                            objectName: "mediaPlayPause"
                            glyphSize: Theme.fontSize
                            implicitHeight: Theme.audioButtonHeight
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
                            glyphSize: Theme.fontSize
                            implicitHeight: Theme.audioButtonHeight
                            glyph: Theme.mediaNextIcon
                            hint: "Next"
                            enabled: !!root.player?.canGoNext
                            onClicked: root.player.next()
                        }
                        AudioButton {
                            objectName: "mediaStop"
                            glyphSize: Theme.fontSize
                            implicitHeight: Theme.audioButtonHeight
                            glyph: Theme.mediaStopIcon
                            hint: "Stop playback"
                            enabled: !!root.player?.canControl
                            onClicked: root.player.stop()
                        }
                    }
                    UI.ColumnText {
                        objectName: "mediaElapsed"
                        font.pixelSize: Theme.fontSize
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
                        font.pixelSize: Theme.fontSize
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
        back: Rectangle {
            objectName: "mediaBack"
            anchors.fill: parent
            enabled: root.flipped && !root.flipping
            color: Theme.alternateBackground
            radius: Theme.audioDeviceRadius
            border.width: root.cardInset
            border.color: Theme.empty

            MediaCardBackground {
                anchors.fill: parent
                anchors.margins: root.cardInset
                radius: root.overlayRadius
                visible: root.showingBack
                artworkSource: artwork.source
            }

            MediaCardVisualizer {
                objectName: "mediaBackVisualizer"
                anchors.fill: parent
                anchors.margins: root.cardInset
                radius: root.overlayRadius
                z: 1
                textureSource: sharedVisualizerTexture
                active: visualizer.rendering && root.showingBack
                opacity: Theme.mediaVisualizerBackOpacity
            }

            MediaEffectList {
                id: effectSelector
                objectName: "mediaEffectSelector"
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: Theme.audioDevicePadding
                width: Math.min(180, parent.width - backActions.width - Theme.audioDevicePadding * 2 - Theme.audioSpacing)
                z: 4
                options: visualizer.effects
                selectedName: visualizer.effect
                onSelected: name => visualizer.selectEffect(name)
            }
            Row {
                id: backActions
                z: 3
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.audioDevicePadding
                spacing: Theme.audioSpacing
                AudioButton {
                    objectName: "mediaFullscreenBack"
                    glyph: Theme.mediaExpandIcon
                    hint: "Fullscreen"
                    enabled: !root.flipping && !root.preparingFullscreen
                    onClicked: root.toggleFullscreen()
                }
                AudioButton {
                    objectName: "mediaFlipBack"
                    glyph: Theme.mediaFlipIcon
                    hint: "Flip to playback controls"
                    visible: !!root.app
                    onClicked: root.flip()
                }
            }
        }
    }
}
