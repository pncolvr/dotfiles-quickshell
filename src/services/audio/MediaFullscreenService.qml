pragma Singleton
import QtQml
import Quickshell
import "../"

Singleton {
    id: root
    property var player: null
    property var audioService: null
    property var mediaService: null
    property var targetScreen: null
    property bool flipped: false
    property bool requested: false
    property bool closing: false
    property rect sourceRect: Qt.rect(0, 0, 0, 0)
    property var snapshot: null
    readonly property bool visible: requested || closing
    readonly property var players: (mediaService?.players ?? []).filter(candidate => MediaService.showPlayer(candidate))
    readonly property int playerIndex: players.indexOf(player)
    signal closed(var player, bool flipped)

    function openPreferred(screen, audioService = AudioService, mediaService = MediaService) {
        if (root.requested) return true;
        const candidates = mediaService.players.filter(candidate => MediaService.showPlayer(candidate));
        const player = candidates.find(candidate => candidate.isPlaying) ?? candidates[0];
        if (!player) return false;
        root.open(player, audioService, mediaService, false, screen);
        TooltipService.dismiss();
        return true;
    }

    function open(player, audioService, mediaService, flipped, screen, sourceRect = Qt.rect(0, 0, 0, 0), snapshot = null) {
        if (!player) return;
        root.audioService = audioService;
        root.mediaService = mediaService;
        root.targetScreen = screen ?? null;
        root.flipped = flipped;
        root.sourceRect = sourceRect;
        root.snapshot = snapshot;
        root.player = player;
        root.requested = true;
        root.closing = false;
    }
    function close(flipped = root.flipped) {
        if (closing) { finishClose(); return; }
        if (!requested) return;
        root.flipped = flipped;
        closing = true;
        requested = false;
    }
    function finishClose() {
        if (requested || !closing) return;
        const previousPlayer = player;
        const previousFace = flipped;
        // Release the surface before any cleanup or subscriber can fail.
        closing = false;
        player = null;
        audioService = null;
        mediaService = null;
        targetScreen = null;
        snapshot = null;
        sourceRect = Qt.rect(0, 0, 0, 0);
        closed(previousPlayer, previousFace);
    }
    function forceClose() {
        closing = true;
        requested = false;
        finishClose();
    }
    Timer {
        interval: 750
        running: root.closing
        onTriggered: root.forceClose()
    }
    function navigate(direction, flipped = root.flipped) {
        if (!requested || players.length < 2) return false;
        root.flipped = flipped;
        player = players[(playerIndex + direction + players.length) % players.length];
        return true;
    }
    // Closing clears mediaService, so wait until the players binding has finished updating.
    onPlayersChanged: Qt.callLater(() => { if (visible && !players.includes(player)) close(); })
}
