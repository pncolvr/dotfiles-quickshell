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
    readonly property bool micActivityEnabled: micMonitor.enabled
    readonly property bool micActive: micActivityEnabled && micActivityRelease.running

    PwNodePeakMonitor {
        id: micMonitor
        node: root.source
        enabled: root.micCaptureNodes.length > 0 && root.source !== null && !root.micMuted
        onEnabledChanged: {
            if (!enabled) micActivityRelease.stop()
        }
        onPeakChanged: {
            if (enabled && peak >= Config.micActivityThreshold)
                micActivityRelease.restart()
        }
    }

    Timer {
        id: micActivityRelease
        interval: Config.micActivityHold
    }

    onSourceChanged: micActivityRelease.stop()
    onMicMutedChanged: micActivityRelease.stop()

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

    // Ignore our peak monitor so it cannot keep itself enabled after apps stop capturing.
    readonly property var micCaptureNodes: Pipewire.nodes.values.filter(node =>
        node.properties?.["media.class"] === "Stream/Input/Audio"
        && node.properties?.["application.name"] !== "Quickshell Peak Detect"
        && node.name !== "quickshell-peak-monitor"
    )

    readonly property var micUsers: micCaptureNodes.map(node => nodeName(node)).filter(name => !!name)

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
