pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"

Singleton {
    id: root
    property bool active: false

    readonly property real cpu: _internal.cpu
    readonly property var cores: _internal.cores
    readonly property real temperature: _internal.temperature

    readonly property real memoryTotal: _internal.memoryTotal
    readonly property real memoryUsed: _internal.memoryUsed
    readonly property real memoryFree: _internal.memoryFree
    readonly property real memoryCache: _internal.memoryCache
    readonly property real memoryAvailable: _internal.memoryAvailable
    readonly property real swapTotal: _internal.swapTotal
    readonly property real swapUsed: _internal.swapUsed
    readonly property real swapFree: _internal.swapFree


    QtObject {
        id: _internal
        property real cpu: 0
        property var cores: []
        property real temperature: 0

        property var _prevCpu: ({})

        property real memoryTotal: 0
        property real memoryUsed: 0
        property real memoryFree: 0
        property real memoryCache: 0
        property real memoryAvailable: 0
        property real swapTotal: 0
        property real swapUsed: 0
        property real swapFree: 0

        property bool _memRead: false
    }

    Timer {
        interval: Config.statsInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProcess.running = true
            memDetailProcess.running = true
            tempProcess.running = true
            // console.debug("updating stats")
        }
    }

    Process {
        id: cpuProcess
        running: true
        command: Config.cpuCommand
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(/\s+/)
                const name = parts[0]
                if (!name.startsWith("cpu")) return
                const idle = parseInt(parts[4]) + parseInt(parts[5])
                const total = parseInt(parts[1]) + parseInt(parts[2]) + parseInt(parts[3])
                    + parseInt(parts[4]) + parseInt(parts[5]) + parseInt(parts[6])
                    + parseInt(parts[7]) + parseInt(parts[8])
                const prev = _internal._prevCpu[name]
                if (prev) {
                    const dt = total - prev.total
                    const di = idle - prev.idle
                    const usage = dt > 0 ? Math.round((dt - di) / dt * 100) : 0
                    if (name === "cpu") {
                        _internal.cpu = usage
                    } else {
                        const idx = parseInt(name.slice(3))
                        const updated = [..._internal.cores]
                        updated[idx] = usage
                        _internal.cores = updated
                    }
                }
                _internal._prevCpu[name] = { idle, total }
            }
        }
    }

    Process {
        id: memDetailProcess
        running: true
        command: Config.memoryDetailCommand
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                if (!_internal._memRead) {
                    _internal.memoryTotal     = parseInt(parts[0])
                    _internal.memoryUsed      = parseInt(parts[1])
                    _internal.memoryFree      = parseInt(parts[2])
                    _internal.memoryCache     = parseInt(parts[3])
                    _internal.memoryAvailable = parseInt(parts[4])
                    _internal._memRead = true
                } else {
                    _internal.swapTotal = parseInt(parts[0])
                    _internal.swapUsed  = parseInt(parts[1])
                    _internal.swapFree  = parseInt(parts[2])
                    _internal._memRead = false
                }
            }
        }
    }

    Process {
        id: tempProcess
        running: true
        command: Config.tempCommand
        stdout: SplitParser {
            onRead: data => _internal.temperature = parseFloat(data) / 1000
        }
    }

    // onCoresChanged: console.warn("cores:", JSON.stringify(cores))
    // onCpuChanged: console.warn("cpu:", cpu)
}