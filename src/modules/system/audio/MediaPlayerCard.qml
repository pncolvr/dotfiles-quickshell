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
    property bool flipped: false
    readonly property bool flipping: flipAnimation.running
    function flip() {
        if (flipping) return;
        effectSelector.expanded = false;
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
    Flipable {
        id: faces
        anchors.fill: parent
        transform: Rotation {
            origin.x: faces.width / 2
            origin.y: faces.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.flipped ? -180 : 0
            Behavior on angle {
                NumberAnimation {
                    id: flipAnimation
                    duration: Theme.mediaFlipDuration
                    easing.type: Easing.InOutCubic
                }
            }
        }
        front: Rectangle {
            objectName: "mediaFront"
            anchors.fill: parent
            enabled: !root.flipped && !root.flipping
            color: Theme.alternateBackground
            radius: Theme.audioDeviceRadius
            border.width: 1
            border.color: Theme.empty
            MediaCardBackground {
                anchors.fill: parent
                anchors.margins: 1
                visible: faces.side === Flipable.Front
                artworkSource: artwork.source
            }
            MediaPosition {
                id: playbackPosition
                objectName: "mediaPositionTracker"
                player: root.player
                mediaService: root.mediaService
                active: root.visible && (root.Window.window?.visible ?? false) && root.monitorPosition
                    && root.hasDuration && !root.flipped && !root.flipping
            }
            AudioButton {
                id: frontFlip
                objectName: "mediaFlip"
                z: 1
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.audioDevicePadding
                glyph: Theme.mediaFlipIcon
                hint: "Flip to audio visualizer"
                visible: !!root.app
                onClicked: root.flip()
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
                        readonly property real detailsTop: (height - details.implicitHeight - volumeHeight) / 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(root.artworkSize, details.implicitHeight + volumeHeight)
                        Column {
                            id: details
                            width: parent.width - (root.app ? frontFlip.width + Theme.audioSpacing : 0)
                            y: Math.max(0, information.detailsTop - Theme.audioSpacing)
                            spacing: Theme.audioSpacing / 2
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
                            UI.ColumnText {
                                objectName: "mediaApp"
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
        back: Rectangle {
            objectName: "mediaBack"
            anchors.fill: parent
            enabled: root.flipped && !root.flipping
            color: Theme.alternateBackground
            radius: Theme.audioDeviceRadius
            border.width: 1
            border.color: Theme.empty

            MediaCardBackground {
                anchors.fill: parent
                anchors.margins: 1
                visible: faces.side === Flipable.Back
                artworkSource: artwork.source
            }

            AudioSelector {
                id: effectSelector
                objectName: "mediaEffectSelector"
                toggleObjectName: "mediaEffectToggle"
                choicesObjectName: "mediaEffectChoices"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Theme.audioDevicePadding
                width: Math.min(180, parent.width - backFlip.width - Theme.audioDevicePadding * 2 - Theme.audioSpacing)
                z: 2
                compact: true
                placeholder: "Effect"
                hint: "Visualizer effect"
                options: visualizer.effects
                selectedName: visualizer.effect
                onSelected: name => visualizer.effect = name
            }
            AudioButton {
                id: backFlip
                objectName: "mediaFlipBack"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.audioDevicePadding
                glyph: Theme.mediaFlipIcon
                hint: "Flip to playback controls"
                visible: !!root.app
                onClicked: root.flip()
            }
            MediaVisualizer {
                id: visualizer
                objectName: "mediaVisualizer"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: backFlip.bottom
                anchors.bottom: visualizerCaption.top
                anchors.margins: Theme.audioDevicePadding
                nodes: root.app?.nodes ?? []
                playing: !!root.player?.isPlaying
                active: root.flipped && !root.flipping && root.visible && root.monitorPosition
                    && (root.Window.window?.visible ?? false)
            }
            Connections {
                target: root.player
                function onTrackChanged() { visualizer.clear(); }
            }
            Column {
                id: visualizerCaption
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.audioDevicePadding
                spacing: Theme.audioSpacing
                UI.ColumnText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.player?.trackTitle || root.player?.identity || "Media player"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }
                UI.ColumnText {
                    objectName: "mediaVisualizerStatus"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.inactive
                    text: visualizer.error ? "Audio visualizer unavailable"
                        : !visualizer.hasStreams ? "Audio stream unavailable"
                        : !root.player?.isPlaying ? "Playback paused"
                        : root.muted ? "Muted" : root.player?.identity || "Playing"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }
            }
        }
    }
}
