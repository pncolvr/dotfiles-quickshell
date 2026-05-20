pragma Singleton

import QtQuick
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
        property var _ifaceSpeeds: ({})
    }

    onActiveChanged: {
        if (active) {
            _internal.speedHistory = []
            _internal._prevNetBytes = {}
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

        property real _totalDown: 0
        property real _totalUp: 0

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(/\s+/)
                if (parts.length < 3) return
                const iface = parts[0]
                if (iface === "lo") return
                const rx = parseInt(parts[1])
                const tx = parseInt(parts[2])
                const prev = _internal._prevNetBytes[iface]
                if (prev) {
                    const interval = Config.statsInterval / 1000
                    const down = Math.max(0, (rx - prev.rx) / interval)
                    const up = Math.max(0, (tx - prev.tx) / interval)
                    const speeds = Object.assign({}, _internal._ifaceSpeeds)
                    speeds[iface] = { down, up }
                    _internal._ifaceSpeeds = speeds
                }
                const bytes = Object.assign({}, _internal._prevNetBytes)
                bytes[iface] = { rx, tx }
                _internal._prevNetBytes = bytes
            }
        }
        onRunningChanged: {
            if (running) {
                _totalDown = 0
                _totalUp = 0
                return
            }
            let totalDown = 0
            let totalUp = 0
            for (const iface in _internal._ifaceSpeeds) {
                totalDown += _internal._ifaceSpeeds[iface].down
                totalUp += _internal._ifaceSpeeds[iface].up
            }
            _internal.downloadSpeed = totalDown
            _internal.uploadSpeed = totalUp
            const maxHistory = 60
            const h = _internal.speedHistory.concat([{ down: totalDown, up: totalUp }])
            _internal.speedHistory = h.length > maxHistory ? h.slice(h.length - maxHistory) : h
        }
    }

    Process {
        id: nmcliProcess
        command: Config.networkConnectionsCommand

        property var _pending: []

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(":")
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
                const parts = data.trim().split(":")
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
