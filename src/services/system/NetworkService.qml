pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../../config"
import "../"

Singleton {
    id: root

    readonly property bool online: _internal.online
    property bool active: false

    readonly property real downloadSpeed: _internal.downloadSpeed
    readonly property real uploadSpeed: _internal.uploadSpeed
    readonly property var speedHistory: _internal.speedHistory
    property var devices: Networking.devices.values
    readonly property var connectedNetworks: collectNetworks(devices, _internal._ifaceSpeeds)
    readonly property var vpnConnections: _internal.vpnConnections

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024) return `${Math.round(bytesPerSec)}B`
        if (bytesPerSec < 1048576) return `${(bytesPerSec / 1024).toFixed(1)}KB`
        if (bytesPerSec < 1073741824) return `${(bytesPerSec / 1048576).toFixed(1)}MB`
        return `${(bytesPerSec / 1073741824).toFixed(1)}GB`
    }

    function collectNetworks(devices, speeds) {
        return devices.map(device => {
            const connected = device.networks.values.find(network => network.connected)
            const speed = speeds[device.name] || {}
            return {device: device.name, name: connected?.name || device.name,
                type: device.type === DeviceType.Wifi ? "wifi" : "ethernet", connected: device.connected,
                downloadSpeed: speed.down || 0, uploadSpeed: speed.up || 0}
        })
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
        property var vpnConnections: []
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
        onTriggered: netDevFile.reload()
    }

    Timer {
        interval: Config.networkConnectionsInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            vpnProcess.running = true
        }
    }

    FileView {
        id: netDevFile
        path: Config.statsProcRoot + "/net/dev"
        preload: root.active
        printErrors: false
        onLoaded: if (root.active) {
            const rows = text().split("\n").slice(2).map(line => {
                const fields = line.trim().replace(":", " ").split(/\s+/)
                return fields.length >= 17 ? fields[0] + " " + fields[1] + " " + fields[9] : ""
            }).join("\n")
            root.applyNetworkSample(rows)
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

    Component.onCompleted: check()
}
