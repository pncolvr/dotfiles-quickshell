pragma Singleton
import QtQml
import Quickshell
import Quickshell.Services.Mpris
import "../../config"

Singleton {
    id: root
    readonly property var players: Mpris.players.values.slice().sort((a,b) =>
        a.identity.localeCompare(b.identity) || a.dbusName.localeCompare(b.dbusName))
    readonly property bool playing: players.some(player => player.isPlaying)
    property var savedVolumes: ({})

    function positionCommand(player) {
        return ["busctl", "--user", "--timeout=2s", "get-property", player.dbusName,
            "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Position"]
    }

    function showPlayer(player) {
        return player.playbackState !== MprisPlaybackState.Stopped || player.canPlay
    }
    function normalized(value) { return String(value || "").toLowerCase().replace(/\.desktop$/, "") }
    function matches(player, app) {
        const names = [player.desktopEntry,player.identity].map(normalized).filter(Boolean)
        return app.nodes.some(node => {
            const props = node.properties || {}
            return [props["application.id"],props["application.name"],props["application.process.binary"]]
                .some(value => value && names.includes(normalized(value)))
        })
    }
    // Only associate a stream when both sides are unique; browsers can expose several players.
    function appForPlayer(player, apps, candidates = players) {
        if (!player) return null
        const matches = apps.filter(app => root.matches(player,app))
        if (matches.length !== 1 || candidates.filter(other => root.matches(other,matches[0])).length !== 1) return null
        return matches[0].nodes.every(node => node.ready && node.audio) ? matches[0] : null
    }
    function volumeSupported(player) { return !!player?.canControl && !!player?.volumeSupported }
    function toggleMute(player) {
        if (!volumeSupported(player)) return
        if (player.volume > 0) {
            savedVolumes = Object.assign({},savedVolumes,{[player.dbusName]:player.volume})
            player.volume = 0
        } else player.volume = savedVolumes[player.dbusName] ?? Config.mediaUnmuteVolume
    }
}
