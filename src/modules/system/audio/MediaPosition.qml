pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../../config"

QtObject {
    id: root
    required property var player
    required property var mediaService
    property bool active: false
    property real sampledPosition: 0
    property bool awaitingTrackPosition: false
    property int generation: 0
    readonly property bool supported: !!player?.positionSupported
    readonly property var queryCommand: mediaService.positionCommand(player)
    readonly property bool queriesPlayer: queryCommand.length > 0
    readonly property real position: {
        if (!supported || awaitingTrackPosition || player.playbackState === MprisPlaybackState.Stopped)
            return 0;
        const seconds = Math.max(0, sampledPosition);
        return player.lengthSupported && player.length > 0 ? Math.min(seconds, player.length) : seconds;
    }

    function refresh() {
        if (!active || !supported)
            return;
        if (!queriesPlayer) {
            player.positionChanged();
            acceptPosition(player.position);
        } else if (!positionQuery.running) {
            positionQuery.requestGeneration = generation;
            positionQuery.command = queryCommand;
            positionQuery.running = true;
        }
    }
    function acceptPosition(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0)
            return;
        sampledPosition = seconds;
        awaitingTrackPosition = false;
    }
    function seekTo(seconds) {
        generation++;
        acceptPosition(seconds);
        player.position = seconds;
        Qt.callLater(refresh);
    }
    onActiveChanged: if (active) Qt.callLater(refresh)
    onPlayerChanged: {
        generation++;
        sampledPosition = 0;
        awaitingTrackPosition = false;
        Qt.callLater(refresh);
    }
    property Timer ticker: Timer {
        objectName: "mediaPositionTimer"
        interval: Config.mediaPositionInterval
        running: root.active && root.supported && !!root.player?.isPlaying
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    property Connections events: Connections {
        target: root.player
        function onTrackChanged() {
            root.generation++;
            root.sampledPosition = 0;
            root.awaitingTrackPosition = root.supported;
            // Metadata and native position signals can arrive in either order.
            if (root.queriesPlayer) Qt.callLater(root.refresh);
        }
        function onPositionChanged() {
            if (root.queriesPlayer)
                Qt.callLater(root.refresh);
            else
                root.acceptPosition(root.player.position);
        }
        function onPlaybackStateChanged() {
            if (root.player.playbackState === MprisPlaybackState.Stopped) {
                root.generation++;
                root.sampledPosition = 0;
            } else if (!root.awaitingTrackPosition) {
                Qt.callLater(root.refresh);
            }
        }
    }
    property Process query: Process {
        id: positionQuery
        property int requestGeneration: 0
        stdout: StdioCollector { id: response; waitForEnd: true }
        onExited: (exitCode, exitStatus) => {
            if (requestGeneration !== root.generation) {
                Qt.callLater(root.refresh);
                return;
            }
            if (exitCode !== 0 || exitStatus !== 0)
                return;
            const match = /^x\s+(\d+)\s*$/.exec(response.text);
            if (match)
                root.acceptPosition(Number(match[1]) / 1000000);
        }
    }
}
