pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Services.Mpris
import "../../src/modules/system/audio"
import "../../src/services"
import "../../src/config"

Scope {
    id: root
    property bool failed: false
    property int step: 0
    property bool screenshotTaken: false
    Test.TestEvent { id: events }
    function check(value,message) { if (!value) { failed = true; console.error("MEDIA FAIL: " + message) } }
    function find(item,name) {
        if (item.objectName === name) return item
        for (const child of item.data ?? item.children ?? []) { const result = find(child,name); if (result) return result }
        return null
    }
    component Player: QtObject {
        property string identity: "Banana"
        property string desktopEntry: "banana"
        property string dbusName: "org.mpris.MediaPlayer2.banana"
        property string trackTitle: "Tomato"
        property string trackArtist: "Potato"
        property string trackAlbum: "Banana"
        property string trackArtUrl: ""
        property bool isPlaying: true
        property int playbackState: MprisPlaybackState.Playing
        property bool canPlay: true
        property bool canPause: true
        property bool canControl: true
        property bool canGoNext: true
        property bool canGoPrevious: true
        property bool volumeSupported: true
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property real position: 65
        property real length: 240
        property real volume: 0.65
        property int nextCalls: 0
        property int previousCalls: 0
        signal trackChanged()
        function play() { if (playbackState === MprisPlaybackState.Stopped) position = 0; isPlaying = true; playbackState = MprisPlaybackState.Playing }
        function pause() { isPlaying = false; playbackState = MprisPlaybackState.Paused }
        function stop() { isPlaying = false; playbackState = MprisPlaybackState.Stopped }
        function next() { nextCalls++ }
        function previous() { previousCalls++ }
    }
    Player { id: banana }
    Player { id: potato; identity: "Potato"; desktopEntry: "potato"; dbusName: "org.mpris.MediaPlayer2.potato"; isPlaying: false; playbackState: MprisPlaybackState.Paused }
    Player { id: duplicate; dbusName: "org.mpris.MediaPlayer2.banana.other" }
    Player { id: queriedPlayer; property real actualPosition: 65 }
    QtObject {
        id: queriedMedia
        function positionCommand(player) {
            return ["bash", "-c", "sleep 0.12; printf 'x %s\\n' \"$1\"", "media-position-test", String(player.actualPosition * 1000000)]
        }
    }
    MediaPosition { id: queriedPosition; player: queriedPlayer; mediaService: queriedMedia }
    QtObject { id: streamAudio; property real volume: 0.4; property bool muted: false }
    QtObject { id: stream; property bool ready: true; property var audio: streamAudio; property var properties: ({"application.id":"banana"}) }
    QtObject {
        id: audio
        property var playbackApps: []
        property var micApps: []
        property var outputDevices: []
        property var inputDevices: []
        property var outputs: []
        property var inputs: []
        property string devicesError: ""
        property bool routingBusy: false
        property string routingError: ""
        property string routingMessage: ""
        property bool micActivityEnabled: true
        function beginPanel() {}
        function endPanel() {}
        function appVolume(app) { return Math.max(...app.nodes.map(node => node.audio.volume)) }
        function appMuted(app) { return app.nodes.every(node => node.audio.muted) }
        function toggleAppMute(app,input) { app.nodes.forEach(node => node.audio.muted = !node.audio.muted) }
        function setAppVolume(app,value) { app.nodes.forEach(node => node.audio.volume = value) }
    }
    QtObject {
        id: media
        property var players: [banana,potato]
        readonly property bool playing: players.some(player => player.isPlaying)
        function appForPlayer(player,apps) { return MediaService.appForPlayer(player,apps,players) }
        function volumeSupported(player) { return MediaService.volumeSupported(player) }
        function toggleMute(player) { MediaService.toggleMute(player) }
        function positionCommand(player) { return [] }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 550
        implicitHeight: output.implicitHeight
        AudioTooltip { id: output; audioService: audio; mediaService: media }
    }
    AudioTooltip { id: input; input: true; audioService: audio; mediaService: media }
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            const panel = root.find(output,"audioMediaPanel")
            if (root.step === 0 && !root.screenshotTaken && Quickshell.env("MEDIA_TEST_SCREENSHOT")) {
                root.screenshotTaken = true
                output.grabToImage(result => result.saveToFile(Quickshell.env("MEDIA_TEST_SCREENSHOT")))
                return
            }
            if (root.step++ === 0) {
                root.check(output.currentIndex === 2 && input.currentIndex === 0, "playing opens Media only for output panel")
                root.check(root.find(output,"mediaPlayers").count === 2 && !!root.find(output,"mediaPlayer_" + potato.dbusName), "all players have cards without a selector")
                root.check(!root.find(output,"mediaPlayerSelector"), "no player combo exists")
                root.check(output.maxPanelHeight > 1080 * 0.6, "Media can use available screen height")
                const card = root.find(output,"mediaPlayer_" + banana.dbusName)
                const timeline = root.find(card,"mediaTimeline")
                const volumeSlider = root.find(card,"mediaVolume")
                const volumeEnd = volumeSlider.mapToItem(card, volumeSlider.width - volumeSlider.rightPadding, 0).x
                const timelineEnd = timeline.mapToItem(card, timeline.width - timeline.rightPadding, 0).x
                root.check(Math.abs(volumeEnd - timelineEnd) < 1, "volume and timeline right endpoints align")
                const art = root.find(card,"mediaArtwork")
                const previous = root.find(card,"mediaPrevious")
                const stopButton = root.find(card,"mediaStop")
                root.check(Math.abs(art.mapToItem(card,0,0).x - previous.mapToItem(card,0,0).x) < 1
                    && Math.abs(art.mapToItem(card,art.width,0).x - stopButton.mapToItem(card,stopButton.width,0).x) < 1,
                    "artwork spans the previous through stop button edges")
                root.check(root.find(card,"mediaTitle").horizontalAlignment === Text.AlignHCenter
                    && root.find(card,"mediaDetails").horizontalAlignment === Text.AlignHCenter,
                    "song details are horizontally centered")
                root.check(root.find(card,"mediaApp").text === banana.identity,
                    "app identity remains visible without playback status")
                root.check(timeline.enabled && root.find(card,"mediaElapsed").text === "1:05" && root.find(card,"mediaDuration").text === "4:00", "timeline shows elapsed and total time")
                events.mousePress(timeline,timeline.width * 0.25,timeline.height / 2,Qt.LeftButton,Qt.NoModifier,0)
                events.mouseMove(timeline,timeline.width * 0.75,timeline.height / 2,0,Qt.LeftButton,Qt.NoModifier)
                events.mouseRelease(timeline,timeline.width * 0.75,timeline.height / 2,Qt.LeftButton,Qt.NoModifier,0)
                root.check(banana.position > 120 && banana.position < 240, "dragging timeline seeks the actual player")
                timeline.volumeMoved(120)
                root.check(banana.position === 120, "scrubbing changes player position in seconds")
                card.seekTo(-10); root.check(banana.position === 0, "seek clamps below zero")
                card.seekTo(999); root.check(banana.position === 240, "seek clamps above duration")
                banana.canSeek = false; timeline.volumeMoved(30)
                root.check(!timeline.enabled && banana.position === 240, "nonseekable player ignores scrubbing")
                banana.canSeek = true; banana.lengthSupported = false
                root.check(!timeline.enabled && root.find(card,"mediaDuration").text === "--:--", "unknown duration does not offer seeking")
                banana.lengthSupported = true; banana.length = 0
                root.check(!timeline.enabled, "zero duration does not offer seeking")
                banana.length = 9223372036854775807 / 1000000
                root.check(!timeline.enabled && timeline.value === 0
                    && !timeline.visible
                    && !root.find(card,"mediaDuration").visible
                    && !root.find(card,"mediaElapsed").visible,
                    "live stream duration sentinel hides the entire timeline")
                banana.length = 240; banana.positionSupported = false
                root.check(!timeline.enabled && !timeline.visible, "missing position hides timeline")
                banana.positionSupported = true
                banana.length = 3665
                root.check(root.find(card,"mediaDuration").text === "1:01:05", "long tracks show hours")
                banana.length = 240
                root.check(root.find(output,"mediaTitle").text === "Tomato", "track metadata appears")
                root.find(output,"mediaNext").clicked(); root.find(output,"mediaPrevious").clicked()
                root.check(banana.nextCalls === 1 && banana.previousCalls === 1, "transport buttons target selected player")
                root.find(output,"mediaPlayPause").clicked()
                root.check(!banana.isPlaying && root.find(output,"mediaPlayPause").hint === "Play", "pause updates state and controls")
                root.find(output,"mediaPlayPause").clicked()
                root.check(banana.isPlaying, "paused player can resume")
                banana.position = 120
                banana.trackChanged()
                banana.trackTitle = "Potato"
                banana.trackArtist = "Tomato"; banana.trackAlbum = "Potato"; banana.length = 262
                root.check(root.find(card,"mediaTitle").text === "Potato"
                    && root.find(card,"mediaDetails").text === "Tomato"
                    && root.find(card,"mediaDuration").text === "4:22" && timeline.to === 262,
                    "new track updates title, artist, duration and timeline range without album information")
                banana.trackArtUrl = "file://" + Quickshell.env("MEDIA_TEST_ART")
                root.check(String(root.find(card,"mediaArtwork").source) === banana.trackArtUrl, "new track updates artwork source")
                root.check(root.find(card,"mediaElapsed").text === "0:00" && timeline.value === 0, "track change clears the previous track position before the new position arrives")
                root.check(root.find(card,"mediaPositionTracker").ticker.running, "position refresh stays active while awaiting the new track")
                banana.playbackStateChanged()
                root.check(timeline.value === 0, "playback state notification does not restore the old track position")
                banana.position = 3
                root.check(root.find(card,"mediaElapsed").text === "0:03" && timeline.value === 3, "new player position resumes elapsed time and timeline")
                root.check(root.find(card,"mediaPositionTracker").ticker.running, "display timer resumes with the new track position")
                root.find(output,"mediaStop").clicked()
                root.check(banana.playbackState === MprisPlaybackState.Stopped, "stop stops playback")
                root.check(root.find(output,"mediaElapsed").text === "0:00" && root.find(output,"mediaTimeline").value === 0, "stop resets displayed elapsed time and timeline even if player position is stale")
                root.find(output,"mediaPlayPause").clicked()
                root.check(root.find(output,"mediaElapsed").text === "0:00" && root.find(output,"mediaTimeline").value === 0, "Play after Stop displays restarted position")
                const mediaMute = root.find(output,"mediaMute")
                const muteWidth = mediaMute.implicitWidth
                const muteHeight = mediaMute.implicitHeight
                mediaMute.clicked()
                root.check(mediaMute.implicitWidth === muteWidth && mediaMute.implicitHeight === muteHeight, "media mute keeps button dimensions")
                root.check(banana.volume === 0, "player volume fallback mutes")
                root.find(output,"mediaMute").clicked()
                root.check(mediaMute.implicitWidth === muteWidth && mediaMute.implicitHeight === muteHeight, "media unmute keeps button dimensions")
                root.check(Math.abs(banana.volume - 0.65) < 0.001, "unmute restores previous player volume")
                root.find(output,"mediaVolume").volumeMoved(0.3)
                root.check(banana.volume === 0.3, "player volume slider targets player")
                banana.pause()
                banana.canGoNext = false; banana.canGoPrevious = false; banana.canPlay = false; banana.canControl = false
                root.check(!root.find(output,"mediaNext").enabled && !root.find(output,"mediaPrevious").enabled
                    && !root.find(output,"mediaPlayPause").enabled && !root.find(output,"mediaStop").enabled
                    && !root.find(output,"mediaMute").enabled, "unsupported controls are disabled")
                banana.canControl = true; banana.canPlay = true
                audio.playbackApps = [{key:"banana",name:"Banana",nodes:[stream],routable:false,deviceName:"",multipleDevices:false}]
                root.find(output,"mediaVolume").volumeMoved(0.8)
                root.check(streamAudio.volume === 0.8 && banana.volume === 0.3, "unique app association reuses stream volume")
                root.find(output,"mediaMute").clicked()
                root.check(streamAudio.muted && banana.volume === 0.3, "stream mute does not alter player volume")
                panel.maximumHeight = 300
                media.players = [banana,duplicate,potato]
                root.find(output,"mediaPlayers").parent.forceLayout(); output.forceLayout()
                root.check(panel.contentHeight > panel.height && panel.height <= panel.maximumHeight, "all-player list scrolls within screen-height limit")
                panel.contentY = 100
                output.currentIndex = 0; output.currentIndex = 2
                root.check(panel.contentY === 100, "switching tabs preserves media scroll position")
                root.check(!MediaService.appForPlayer(banana,audio.playbackApps,media.players), "multiple players from same app prevent ambiguous stream control")
                root.check(!MediaService.appForPlayer(banana,[{nodes:[stream]},{nodes:[stream]}],[banana]), "multiple app matches prevent ambiguous stream control")
                stream.ready = false
                root.check(!MediaService.appForPlayer(banana,audio.playbackApps,[banana]), "unready streams are rejected")
                stream.ready = true
                media.players = [potato,banana]
                root.check(root.find(output,"mediaPlayers").count === 2 && !!root.find(output,"mediaPlayer_" + banana.dbusName) && !!root.find(output,"mediaPlayer_" + potato.dbusName), "all remaining player cards stay available")
                banana.trackArtUrl = "file://" + Quickshell.env("MEDIA_TEST_ART")
                media.players = [banana]
                root.check(root.find(output,"mediaPlayers").count === 1, "closed players remove their card")
                banana.stop(); banana.canPlay = false
                root.check(root.find(output,"mediaPlayers").count === 0, "stopped player without Play is hidden")
                banana.canPlay = true
                root.check(root.find(output,"mediaPlayers").count === 1, "stopped player that supports Play remains available")
                banana.canPlay = false; banana.pause()
                root.check(root.find(output,"mediaPlayers").count === 1, "paused player remains visible")
                banana.play()
                root.check(root.find(output,"mediaPlayers").count === 1, "playing player remains visible even without Play capability")
                banana.canPlay = true
                output.currentIndex = 0
                banana.play()
                root.check(!root.find(output,"mediaPositionTracker").ticker.running, "position polling stops when Media is hidden")
                root.check(output.currentIndex === 0, "playback changes do not steal selected tab")
                queriedPosition.active = true
            } else {
                if (root.step === 2) {
                    output.currentIndex = 2
                    root.check(queriedPosition.position === 65, "direct position query supplies elapsed time")
                    queriedPlayer.position = 440
                    queriedPlayer.trackChanged()
                    queriedPlayer.length = 262; queriedPlayer.actualPosition = 0
                    queriedPlayer.positionChanged()
                    root.check(queriedPosition.position === 0, "late native position does not restore elapsed time from the old track")
                    return
                }
                if (root.step === 3) {
                    root.check(queriedPosition.position === 0, "direct query ignores the stale native position estimate")
                    queriedPlayer.actualPosition = 110
                    queriedPosition.refresh()
                    queriedPlayer.trackChanged(); queriedPlayer.actualPosition = 0
                    return
                }
                if (root.step === 4) {
                    root.check(queriedPosition.position === 0, "response requested for a previous track is discarded")
                    return
                }
                if (root.step === 5) {
                    root.check(queriedPosition.position === 0, "new track is queried after an obsolete response finishes")
                    queriedPlayer.actualPosition = 7; queriedPlayer.positionChanged()
                    return
                }
                if (root.step === 6) {
                    root.check(queriedPosition.position === 7, "elapsed time advances using fresh player position")
                    queriedPlayer.actualPosition = 999; queriedPlayer.positionChanged()
                    return
                }
                root.check(queriedPosition.position === 262, "elapsed time stays within the new track duration")
                queriedPosition.active = false
                root.check(!queriedPosition.ticker.running, "hiding the card stops direct position polling")
                root.check(root.find(output,"mediaArtwork").status === Image.Ready, "provided artwork loads")
                media.players = []
                root.check(root.find(output,"mediaPlayers").count === 0, "last player removal shows empty state")
                if (!root.failed) console.log("PASS: media controls, capability gating, artwork, seeking, all-player list and volume association")
                stop(); Qt.quit()
            }
        }
    }
}
