pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root

    readonly property bool online: _internal.online
    property bool active: false

    readonly property real downloadSpeed: _internal.downloadSpeed
    readonly property real uploadSpeed: _internal.uploadSpeed
    readonly property var speedHistory: _internal.speedHistory
    readonly property var connectedNetworks: _internal.connectedNetworks
    readonly property var vpnConnections: _internal.vpnConnections
    readonly property var topProcesses: _internal.topProcesses

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024) return `${Math.round(bytesPerSec)}B`
        if (bytesPerSec < 1048576) return `${(bytesPerSec / 1024).toFixed(1)}KB`
        if (bytesPerSec < 1073741824) return `${(bytesPerSec / 1048576).toFixed(1)}MB`
        return `${(bytesPerSec / 1073741824).toFixed(1)}GB`
    }

    function splitNmcli(line) {
        const fields = []
        let field = ""
        for (let index = 0; index < line.length; index++) {
            const character = line[index]
            if (character === "\\" && [":", "\\"].includes(line[index + 1])) field += line[++index]
            else if (character === ":") { fields.push(field); field = "" }
            else field += character
        }
        fields.push(field)
        return fields
    }

    function applyNetworkSample(output, timestamp = Date.now()) {
        const bytes = {}
        const speeds = {}
        const interval = (timestamp - _internal._prevNetTimestamp) / 1000
        for (const line of output.trim().split("\n")) {
            const parts = line.trim().split(/\s+/)
            if (parts.length !== 3 || parts[0] === "lo") continue
            const iface = parts[0]
            const rx = Number(parts[1]); const tx = Number(parts[2])
            if (!Number.isFinite(rx) || !Number.isFinite(tx) || rx < 0 || tx < 0) continue
            const prev = _internal._prevNetBytes[iface]
            bytes[iface] = {rx, tx}
            speeds[iface] = {
                down: prev && interval > 0 ? Math.max(0, (rx - prev.rx) / interval) : 0,
                up: prev && interval > 0 ? Math.max(0, (tx - prev.tx) / interval) : 0
            }
        }
        // Replace the whole snapshot so disconnected interfaces lose their rate and baseline.
        _internal._prevNetBytes = bytes
        _internal._prevNetTimestamp = timestamp
        _internal._ifaceSpeeds = speeds
        _internal.downloadSpeed = Object.values(speeds).reduce((sum, speed) => sum + speed.down, 0)
        _internal.uploadSpeed = Object.values(speeds).reduce((sum, speed) => sum + speed.up, 0)
        const history = _internal.speedHistory.concat([{down: root.downloadSpeed, up: root.uploadSpeed}])
        _internal.speedHistory = history.slice(-60)
    }

    QtObject {
        id: _internal
        property bool online: false
        property real downloadSpeed: 0
        property real uploadSpeed: 0
        property var speedHistory: []
        property var connectedNetworks: []
        property var vpnConnections: []
        property var topProcesses: []
        property var _prevNetBytes: ({})
        property real _prevNetTimestamp: 0
        property var _ifaceSpeeds: ({})
    }

    onActiveChanged: {
        if (active) {
            _internal.speedHistory = []
            _internal._prevNetBytes = {}
            _internal._prevNetTimestamp = 0
            _internal._ifaceSpeeds = {}
        }
    }

    function check() {
        networkCheckProcess.running = true
    }

    Process {
        id: networkCheckProcess
        command: Config.networkCheckCommand
        stdout: SplitParser {
            onRead: data => {
                _internal.online = data.trim() === "1"
            }
        }
        onRunningChanged: {
            if (!running) {
                if (!_internal.online) {
                    AlertService.post("network", "no internet access")
                    retryTimer.start()
                } else {
                    AlertService.dismiss("network")
                }
            }
        }
    }

    Timer {
        id: retryTimer
        interval: Config.networkRetryInterval
        onTriggered: root.check()
    }

    Timer {
        id: periodicTimer
        interval: Config.networkAlertInterval
        running: _internal.online
        repeat: true
        onTriggered: root.check()
    }

    // --- stats polling ---

    Timer {
        interval: Config.statsInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: netDevProcess.running = true
    }

    Timer {
        interval: Config.networkConnectionsInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            nmcliProcess.running = true
            vpnProcess.running = true
        }
    }

    Timer {
        interval: Config.networkProcessesInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: nethogProcess.running = true
    }

    Process {
        id: netDevProcess
        command: Config.networkStatsCommand
        stdout: StdioCollector { id: netOutput; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (root.active && exitCode === 0 && exitStatus === 0) root.applyNetworkSample(netOutput.text)
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: nmcliProcess
        command: Config.networkConnectionsCommand

        property var _pending: []

        stdout: SplitParser {
            onRead: data => {
                const parts = root.splitNmcli(data)
                if (parts.length < 4) return
                const device = parts[0]
                const name = parts[1]
                const type = parts[2]
                const state = parts.slice(3).join(":")
                if (type === "loopback") return
                const connected = state.startsWith("connected")
                const displayName = (name && name !== "--") ? name : device
                nmcliProcess._pending.push({ device, name: displayName, type, connected })
            }
        }
        onRunningChanged: {
            if (running) {
                _pending = []
                return
            }
            _internal.connectedNetworks = _pending.map(n => ({
                device: n.device,
                name: n.name,
                type: n.type,
                connected: n.connected,
                downloadSpeed: (_internal._ifaceSpeeds[n.device] || {}).down || 0,
                uploadSpeed: (_internal._ifaceSpeeds[n.device] || {}).up || 0
            }))
        }
    }

    Process {
        id: vpnProcess
        command: Config.networkVpnCommand

        property var _pending: []

        stdout: SplitParser {
            onRead: data => {
                const parts = root.splitNmcli(data)
                if (parts.length < 2) return
                const name = parts[0]
                const type = parts[1]
                const state = parts[2] || ""
                vpnProcess._pending.push({
                    name,
                    type,
                    active: state === "activated" || state === "activating"
                })
            }
        }
        onRunningChanged: {
            if (running) {
                _pending = []
                return
            }
            _internal.vpnConnections = _pending
        }
    }

    Process {
        id: nethogProcess
        command: Config.networkProcessesCommand

        property var _pending: []

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("|")
                if (parts.length < 3) return
                nethogProcess._pending.push({
                    program: parts[0],
                    sent: parseInt(parts[1]),
                    received: parseInt(parts[2])
                })
            }
        }
        onRunningChanged: {
            if (running) {
                _pending = []
                return
            }
            _internal.topProcesses = _pending
        }
    }

    Component.onCompleted: check()
}
