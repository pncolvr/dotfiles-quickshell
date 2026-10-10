pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../config"
import "." as AudioModels

Singleton {
    id: root

    PwObjectTracker {
        objects: [root.sink, root.source, ...Pipewire.nodes.values]
    }

    // Output
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property var outputs: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && node.isSink)
    readonly property var inputs: Pipewire.nodes.values.filter(node => node.audio && !node.isStream && !node.isSink)
    readonly property var outputDevices: withInactiveCards(outputs, false)
    readonly property var inputDevices: withInactiveCards(inputs, true)
    readonly property var cards: devicesState.snapshot.cards
    readonly property string devicesError: devicesState.error
    readonly property bool profileBusy: profileProcess.running

    QtObject {
        id: devicesState
        property int panels: 0
        property var snapshot: ({cards: [], nodes: []})
        property string error: ""
    }

    function beginPanel() { devicesState.panels++; refreshDevices() }
    function endPanel() { devicesState.panels = Math.max(0, devicesState.panels - 1) }
    function refreshDevices() {
        if (devicesState.panels > 0 && !deviceProcess.running && !profileBusy) deviceProcess.running = true
    }

    Timer {
        interval: Config.audioDevicesInterval
        running: devicesState.panels > 0
        repeat: true
        onTriggered: root.refreshDevices()
    }

    Process {
        id: deviceProcess
        command: [...Config.audioDevicesCommand, "list"]
        stdout: StdioCollector { id: deviceOutput; waitForEnd: true }
        stderr: StdioCollector { id: deviceError; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) {
                devicesState.error = deviceError.text.trim() || "Could not read audio device profiles."
                return
            }
            try {
                const snapshot = JSON.parse(deviceOutput.text)
                if (!Array.isArray(snapshot.cards) || !Array.isArray(snapshot.nodes)) throw new Error("Invalid audio devices")
                devicesState.snapshot = snapshot
                devicesState.error = ""
            } catch (error) { devicesState.error = "Could not read audio device profiles." }
        }
        // qmllint enable signal-handler-parameters
    }

    function cardForNode(node) {
        const name = node?.cardName || devicesState.snapshot.nodes.find(device => device.name === node?.name)?.cardName
        return cards.find(card => card.name === name) ?? null
    }

    function withInactiveCards(nodes, input) {
        return [...nodes, ...cards.filter(card =>
            card.profiles.some(profile => input ? profile.input : profile.output)
            && !nodes.some(node => cardForNode(node)?.name === card.name)
        ).map(card => ({name: "card:" + card.name, description: card.description, cardName: card.name,
            ready: false, audio: null}))].sort((a, b) => deviceName(a).localeCompare(deviceName(b)) || a.name.localeCompare(b.name))
    }

    function setProfile(card, profile) {
        if (profileBusy || !card || !card.profiles.some(item => item.name === profile && item.available)) return
        devicesState.error = ""
        profileProcess.command = [...Config.audioDevicesCommand, "set-profile", card.name, profile]
        profileProcess.running = true
    }

    Process {
        id: profileProcess
        stderr: StdioCollector { id: profileError; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0)
                devicesState.error = profileError.text.trim() || "Could not change the audio device profile."
            else root.refreshDevices()
        }
        // qmllint enable signal-handler-parameters
    }

    function deviceName(node) {
        return node?.description || node?.nickname || node?.name || "Audio device"
    }

    function devices(input) { return input ? inputs : outputs }
    function isDefault(node, input) { return node === (input ? source : sink) }

    function deviceInUse(node, input) {
        const apps = input ? micCaptureNodes : audioPlaybackNodes
        return Pipewire.linkGroups.values.some(group =>
            (input ? group.source : group.target) === node
            && apps.includes(input ? group.target : group.source)
        )
    }

    function setDefault(node, input) {
        if (!node?.ready || !devices(input).includes(node)) return
        if (input) Pipewire.preferredDefaultAudioSource = node
        else Pipewire.preferredDefaultAudioSink = node
    }

    function toggleNodeMute(node) {
        if (node?.ready && node.audio) node.audio.muted = !node.audio.muted
    }

    function setNodeVolume(node, value) {
        if (node?.ready && node.audio && Number.isFinite(value))
            node.audio.volume = Math.max(0, Math.min(Config.audioMaxVolume, value))
    }

    function toggleMute() {
        toggleNodeMute(sink)
    }

    function setVolume(v: real) {
        setNodeVolume(sink, v)
    }

    // Input
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
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
        toggleNodeMute(source)
    }

    function setMicVolume(v: real) {
        setNodeVolume(source, v)
    }

    property string routingError: ""
    property string routingMessage: ""
    readonly property bool routingBusy: routeProcess.running

    function useNow(node, input) {
        if (routingBusy || !node?.ready || !devices(input).includes(node)) return
        routingError = ""
        routingMessage = ""
        routeProcess.command = Config.audioRouteCommand(input, node.name)
        routeProcess.running = true
    }

    function moveApp(app, node, input) {
        const apps = input ? micApps : playbackApps
        const current = apps.find(item => item.key === app?.key)
        if (routingBusy || !node?.ready || !devices(input).includes(node) || !current?.routable) return
        routingError = ""
        routingMessage = ""
        routeProcess.command = [...Config.audioRouteCommand(input, node.name), ...current.serials]
        routeProcess.running = true
    }

    function toggleAppMute(app, input) {
        const current = (input ? micApps : playbackApps).find(item => item.key === app?.key)
        if (!current) return
        setAppMute(current, !appMuted(current))
    }

    function appMuted(app) {
        return !!app?.nodes?.length && app.nodes.every(node => node.audio?.muted === true)
    }

    function appVolume(app) {
        return Math.max(0, ...(app?.nodes ?? []).map(node => node.audio?.volume ?? 0))
    }

    function setAppVolume(app, value) {
        for (const node of app?.nodes ?? []) setNodeVolume(node, value)
    }

    function setAppMute(app, muted) {
        for (const node of app?.nodes ?? []) {
            if (node?.ready && node.audio) node.audio.muted = muted
        }
    }

    Process {
        id: routeProcess
        stdout: StdioCollector { id: routeOutput; waitForEnd: true }
        stderr: StdioCollector { id: routeError; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitStatus !== 0 || exitCode !== 0)
                root.routingError = routeError.text.trim() || "Could not switch the current apps."
            else root.routingMessage = routeOutput.text.trim()
        }
        // qmllint enable signal-handler-parameters
    }

    function openMixer() {
        mixerProcess.running = true
    }

    Process {
        id: mixerProcess
        command: Config.mixerCommand
    }

    AudioModels.ScreencastModel {
        id: screencastModel
        nodes: Pipewire.nodes.values
        links: Pipewire.links.values
    }
    readonly property var screencastStreams: screencastModel.streams
    readonly property bool screencastActive: screencastStreams.length > 0
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

    readonly property var audioPlaybackNodes: Pipewire.nodes.values.filter(node =>
        node.properties?.["media.class"] === "Stream/Output/Audio" && !!nodeName(node)
    )
    readonly property var audioUsers: audioPlaybackNodes.map(node => nodeName(node))

    readonly property var micApps: appEntries(micCaptureNodes, true, Pipewire.linkGroups.values, inputs)
    readonly property var playbackApps: appEntries(audioPlaybackNodes, false, Pipewire.linkGroups.values, outputs)

    function appEntries(nodes, input, links, targets) {
        const apps = new Map()
        for (const node of nodes) {
            const name = nodeName(node)
            if (!name) continue
            const properties = node.properties ?? {}
            const processId = properties["application.process.id"]
            const key = processId ? "process:" + processId : "app:" + (properties["application.id"] || name)
            if (!apps.has(key)) apps.set(key, {key: key, name: name, serials: [], nodes: [], devices: new Set()})
            const app = apps.get(key)
            app.nodes.push(node)
            const serial = String(properties["object.serial"] ?? "")
            if (/^[0-9]+$/.test(serial)) app.serials.push(serial)
            for (const link of links) {
                if ((input ? link.target : link.source) !== node) continue
                const device = input ? link.source : link.target
                if (targets.includes(device)) app.devices.add(device.name)
            }
        }
        return [...apps.values()].map(app => ({
            key: app.key, name: app.name, serials: [...new Set(app.serials)], nodes: app.nodes,
            routable: app.serials.length === app.nodes.length,
            deviceName: app.devices.size === 1 ? [...app.devices][0] : "",
            multipleDevices: app.devices.size > 1
        })).sort((a, b) => a.name.localeCompare(b.name) || a.key.localeCompare(b.key))
    }
}
