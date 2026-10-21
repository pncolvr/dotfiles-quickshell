pragma Singleton

import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../config"
import "." as AudioModels
import "CaptureAudio.mjs" as CaptureAudio

Singleton {
    id: root
    // Native module metadata exposes these ObjectModels as opaque types.
    readonly property var nodesModel: Pipewire.nodes
    readonly property var linksModel: Pipewire.links
    readonly property var linkGroupsModel: Pipewire.linkGroups

    PwObjectTracker {
        // Link state is unavailable until its group is bound, just like node audio.
        objects: [root.sink, root.source, ...root.nodesModel.values,
            ...root.linkGroupsModel.values.filter(link => link.source === root.source || link.target === root.sink
                || (root.screencastActive && root.micCaptureNodes.includes(link.target)))]
    }

    // Output
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool outputMutePulse: muted && hasDeviceRequest(sink, false, audioPlaybackNodes, root.linkGroupsModel.values)

    readonly property var outputs: root.nodesModel.values.filter(node => node.audio && !node.isStream && node.isSink)
    readonly property var inputs: root.nodesModel.values.filter(node => node.audio && !node.isStream && !node.isSink)
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
                devicesState.error = deviceError.text.trim() || Translations.text("audio.errors.readProfiles")
                return
            }
            try {
                const snapshot = JSON.parse(deviceOutput.text)
                if (!Array.isArray(snapshot.cards) || !Array.isArray(snapshot.nodes)) throw new Error(Translations.text("audio.errors.invalidDevices"))
                devicesState.snapshot = snapshot
                devicesState.error = ""
            } catch (error) { devicesState.error = Translations.text("audio.errors.readProfiles") }
        }
        // qmllint enable signal-handler-parameters
    }

    function cardForNode(node, snapshot = devicesState.snapshot) {
        const name = node?.cardName || snapshot.nodes.find(device => device.name === node?.name)?.cardName
        return snapshot.cards.find(card => card.name === name) ?? null
    }

    function withInactiveCards(nodes, input, snapshot = devicesState.snapshot) {
        return [...nodes, ...snapshot.cards.filter(card =>
            card.profiles.some(profile => input ? profile.input : profile.output)
            && !nodes.some(node => cardForNode(node, snapshot)?.name === card.name)
        ).map(card => ({name: "card:" + card.name, description: card.description, cardName: card.name,
            ready: false, audio: null}))].sort((a, b) => {
            const aOff = cardForNode(a, snapshot)?.activeProfile === "off"
            const bOff = cardForNode(b, snapshot)?.activeProfile === "off"
            return Number(aOff) - Number(bOff)
                || deviceName(a).localeCompare(deviceName(b)) || a.name.localeCompare(b.name)
        })
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
                devicesState.error = profileError.text.trim() || Translations.text("audio.errors.changeProfile")
            else root.refreshDevices()
        }
        // qmllint enable signal-handler-parameters
    }

    function deviceName(node) {
        return node?.description || node?.nickname || node?.name || Translations.text("audio.device.fallbackName")
    }

    function devices(input) { return input ? inputs : outputs }
    function isDefault(node, input) { return node === (input ? source : sink) }

    function deviceInUse(node, input) {
        const apps = input ? micCaptureNodes : audioPlaybackNodes
        return root.linkGroupsModel.values.some(group =>
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
    readonly property bool micMutePulse: micMuted && hasDeviceRequest(source, true, micCaptureNodes, root.linkGroupsModel.values)
    readonly property bool micActivityEnabled: micMonitor.enabled
    readonly property bool micActive: micActivityEnabled && micActivityRelease.running

    PwNodePeakMonitor {
        id: micMonitor
        node: root.source
        enabled: !root.micMuted && root.hasDeviceRequest(root.source, true, root.micCaptureNodes, root.linkGroupsModel.values)
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
                root.routingError = Translations.message(routeError.text.trim()) || Translations.text("audio.errors.moveApps")
            else root.routingMessage = Translations.message(routeOutput.text.trim())
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
        nodes: root.nodesModel.values
        links: root.linksModel.values
    }
    readonly property var screencastStreams: screencastModel.streams
    // Initial registry sync alone may precede tracked node properties.
    readonly property bool screencastReady: Pipewire.ready && root.nodesModel.values.every(node => node.ready)
    readonly property bool screencastActive: screencastStreams.length > 0
    readonly property string screencastAudioStatus: screencastActive
        ? CaptureAudio.captureStatus(micCaptureNodes, root.linkGroupsModel.values, PwLinkState.Active) : "unknown"
    AudioModels.ScreenShareAlert {
        active: root.screencastActive
        ready: root.screencastReady
        audioStatus: root.screencastAudioStatus
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

    // Internal monitors must not appear as microphone users or keep mic activity enabled.
    readonly property var micCaptureNodes: root.nodesModel.values.filter(node =>
        node.properties?.["media.class"] === "Stream/Input/Audio"
        && node.properties?.["application.name"] !== "Quickshell Peak Detect"
        && node.name !== "quickshell-peak-monitor"
        && node.properties?.["application.name"] !== "Quickshell Spectrum Detect"
        && node.name !== "quickshell-spectrum-monitor"
    )

    readonly property var micUsers: micCaptureNodes.map(node => nodeName(node)).filter(name => !!name)

    readonly property var audioPlaybackNodes: root.nodesModel.values.filter(node =>
        node.properties?.["media.class"] === "Stream/Output/Audio" && !!nodeName(node)
    )
    readonly property var audioUsers: audioPlaybackNodes.map(node => nodeName(node))

    function hasDeviceRequest(device, input, streams, links) {
        if (!device) return false
        return links.some(link => link.state === PwLinkState.Active
            && (input ? link.source : link.target) === device
            && streams.includes(input ? link.target : link.source))
    }

    readonly property var micApps: appEntries(micCaptureNodes, true, root.linkGroupsModel.values, inputs)
    readonly property var playbackApps: appEntries(audioPlaybackNodes, false, root.linkGroupsModel.values, outputs)

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
