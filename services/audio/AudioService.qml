pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../config"

Singleton {
    id: root

    PwObjectTracker {
        objects: [root.sink, root.source, ...Pipewire.nodes.values]
    }

    // Output
    property PwNode sink: Pipewire.defaultAudioSink
    property real volume: sink?.audio?.volume ?? 0
    property bool muted: sink?.audio?.muted ?? false

    function toggleMute() {
        sink.audio.muted = !sink.audio.muted
    }

    function setVolume(v: real) {
        sink.audio.volume = v
    }

    // Input
    property PwNode source: {
        for (const node of Pipewire.nodes.values) {
            if (node.name?.includes(Config.preferredMicName)) return node
        }
        return Pipewire.defaultAudioSource
    }

    property bool micMuted: source?.audio?.muted ?? false

    function toggleMicMute() {
        if (source?.audio) source.audio.muted = !source.audio.muted
    }

    function openMixer() {
        mixerProcess.running = true
    }

    Process {
        id: mixerProcess
        command: Config.mixerCommand
    }

    readonly property bool screencastActive: {
        for (const node of Pipewire.nodes.values) {
            if (node.properties?.["media.class"] === "Stream/Input/Video") return true
        }
        return false
    }

    onScreencastActiveChanged: {
        const sound = screencastActive ? Config.screencastStartSound : Config.screencastStopSound
        screencastSound.command = Config.screencastSoundCommand(sound)
        screencastSound.running = true
    }

    Process { id: screencastSound }

    function nodeName(node) {
        return node.properties?.["node.nick"]
            ?? node.properties?.["application.process.binary"]
            ?? node.properties?.["application.name"]
    }

    readonly property var micUsers: {
        const apps = []
        for (const node of Pipewire.nodes.values) {
            if (node.properties?.["media.class"] !== "Stream/Input/Audio") continue
            const name = nodeName(node)
            if (name) apps.push(name)
        }
        return apps
    }

    readonly property var audioUsers: {
        const apps = []
        for (const node of Pipewire.nodes.values) {
            if (node.properties?.["media.class"] !== "Stream/Output/Audio") continue
            const name = nodeName(node)
            if (name) apps.push(name)
        }
        return apps
    }
}
