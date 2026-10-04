pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../../config"
import "../"

Singleton {
    id: root

    // Reading device properties inside this binding also tracks their live changes.
    readonly property var batteries: mergeReceiverBatteries(
        collectBatteries(UPower.devices.values, Bluetooth.devices.values, UPower.onBattery), receiverBatteries)
    readonly property var receiverBatteries: JSON.parse(_internal.receiverSnapshotJson)
    readonly property bool scanningReceivers: receiverProcess.running
    readonly property string receiverError: _internal.receiverError
    readonly property real lowestPercentage: {
        const levels = batteries.filter(battery => battery.percentage !== null).map(battery => battery.percentage)
        return levels.length > 0 ? Math.min(...levels) : -1
    }
    readonly property string lowestLevelStatus: levelStatus(lowestPercentage)

    PersistentProperties {
        id: _internal
        reloadableId: "battery-receiver-cache"
        // Strings survive reloads across QML engines; JavaScript arrays do not.
        property string receiverSnapshotJson: "[]"
        property bool receiverCacheRestored: false
        property string receiverError: ""
    }

    Timer {
        objectName: "batteryReceiverTimer"
        interval: Config.batteryReceiverInterval
        // The bar needs current levels even when the tooltip has never been opened.
        running: DbService.ready
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!receiverProcess.running) receiverProcess.running = true
    }

    Connections {
        target: DbService
        function onReadyChanged() { root.restoreReceiverSnapshot() }
    }

    function restoreReceiverSnapshot() {
        if (!DbService.ready || _internal.receiverCacheRestored) return
        _internal.receiverSnapshotJson = JSON.stringify(BatteryRepository.receiverSnapshot())
        _internal.receiverCacheRestored = true
    }

    Component.onCompleted: restoreReceiverSnapshot()

    function levelStatus(level) {
        if (typeof level !== "number" || !Number.isFinite(level) || level < 0) return "normal"
        if (level <= Config.batteryCriticalThreshold) return "critical"
        if (level <= Config.batteryLowThreshold) return "low"
        return "normal"
    }

    Process {
        id: receiverProcess
        command: Config.batteryReceiverCommand
        stdout: StdioCollector {
            id: receiverOutput
            waitForEnd: true
        }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) {
                _internal.receiverError = "Some device batteries could not be read"
                return
            }
            try {
                const snapshot = JSON.parse(receiverOutput.text)
                if (!snapshot || !Array.isArray(snapshot.devices) || typeof snapshot.error !== "string")
                    throw new Error("Invalid receiver snapshot")
                if (snapshot.error) {
                    _internal.receiverError = snapshot.error
                    return
                }
                // Keep the previous readings throughout the scan; replace them in one update.
                // An empty successful snapshot confirms that receiver devices disconnected.
                const devices = receiverSnapshot(root.receiverBatteries, snapshot.devices)
                _internal.receiverSnapshotJson = JSON.stringify(devices)
                BatteryRepository.saveReceiverSnapshot(devices)
                _internal.receiverError = ""
            } catch (error) {
                _internal.receiverError = "Some device batteries could not be read"
            }
        }
        // qmllint enable signal-handler-parameters
    }

    function receiverSnapshot(previous, incoming) {
        return incoming.map(device => {
            const last = previous.find(battery => battery.id === device.id)
            // A listed, connected device can temporarily report N/A instead of a level.
            return device.percentage === null && last?.percentage !== null && last?.percentage !== undefined
                ? Object.assign({}, device, {percentage: last.percentage}) : device
        })
    }

    function mergeReceiverBatteries(nativeBatteries, receiverBatteries) {
        const result = nativeBatteries.map(battery => Object.assign({}, battery))
        for (const receiver of receiverBatteries) {
            const pathMatch = result.find(battery => receiver.nativePath && battery.id === "upower:" + receiver.nativePath)
            // Some receivers have no kernel power_supply node. Match unique names only.
            const nameMatches = nativeBatteries.filter(battery => battery.name === receiver.name)
            const receiverMatches = receiverBatteries.filter(battery => battery.name === receiver.name)
            const match = pathMatch ?? (nameMatches.length === 1 && receiverMatches.length === 1
                ? result.find(battery => battery.id === nameMatches[0].id) : null)
            if (match) {
                if (!match.brand) match.brand = receiver.brand
                if (match.percentage === null) match.percentage = receiver.percentage
                if (match.state === "unknown") {
                    match.state = receiver.state
                    match.pluggedIn = match.pluggedIn || receiver.pluggedIn
                }
            } else result.push(receiver)
        }
        return result.sort((a, b) => Number(b.internal) - Number(a.internal) || a.name.localeCompare(b.name) || a.id.localeCompare(b.id))
    }

    function addressFromPath(path) {
        const match = String(path ?? "").match(/(?:[0-9a-f]{2}[:_-]){5}[0-9a-f]{2}/i)
        return match ? match[0].replace(/[:-]/g, "_").toUpperCase() : ""
    }

    function bluetoothMatch(device, bluetoothDevices) {
        const path = device.nativePath ?? ""
        const address = addressFromPath(path)
        return bluetoothDevices.find(bluetooth =>
            path === bluetooth.dbusPath || (address && address === addressFromPath(bluetooth.address)))
    }

    function percentage(level) {
        return typeof level === "number" && Number.isFinite(level)
            ? Math.max(0, Math.min(100, level * 100)) : null
    }

    function stateName(state) {
        switch (state) {
        case UPowerDeviceState.Charging: return "charging"
        case UPowerDeviceState.Discharging: return "discharging"
        case UPowerDeviceState.Empty: return "empty"
        case UPowerDeviceState.FullyCharged: return "charged"
        case UPowerDeviceState.PendingCharge: return "pending-charge"
        case UPowerDeviceState.PendingDischarge: return "pending-discharge"
        default: return "unknown"
        }
    }

    function collectBatteries(powerDevices, bluetoothDevices, onBattery) {
        const result = []
        const matchedPaths = new Set()
        for (let i = 0; i < powerDevices.length; ++i) {
            const device = powerDevices[i]
            if (!device.ready || device.type === UPowerDeviceType.LinePower || device.type === UPowerDeviceType.Unknown)
                continue
            // IsPresent is only defined for batteries, not mice, keyboards, etc.
            if (device.type === UPowerDeviceType.Battery && !device.isPresent) continue
            const bluetooth = bluetoothMatch(device, bluetoothDevices)
            if (bluetooth) {
                matchedPaths.add(bluetooth.dbusPath)
                if (!bluetooth.connected) continue
            }
            const internal = device.isLaptopBattery
            const path = device.nativePath ?? ""
            const slot = path.split("/").pop()
            const state = stateName(device.state)
            result.push({
                id: "upower:" + (path || i),
                name: internal ? "Laptop battery" + (slot ? " · " + slot : "")
                    : bluetooth?.name || device.model || UPowerDeviceType.toString(device.type) || "Battery-powered device",
                internal: internal,
                percentage: percentage(device.percentage),
                state: state,
                // PowerSupply means this battery powers the host, not that it is plugged in.
                pluggedIn: state === "charging" || state === "pending-charge"
                    || (device.iconName ?? "").includes("charging") || (internal && !onBattery),
                timeToFull: device.timeToFull,
                timeToEmpty: device.timeToEmpty
            })
        }
        for (const device of bluetoothDevices) {
            if (!device.connected || !device.batteryAvailable || matchedPaths.has(device.dbusPath)) continue
            result.push({
                id: "bluetooth:" + device.dbusPath,
                name: device.name || device.deviceName || "Bluetooth device",
                internal: false,
                percentage: percentage(device.battery),
                // BlueZ Battery1 reports a level, without charging state or time estimates.
                state: "unknown",
                pluggedIn: false,
                timeToFull: 0,
                timeToEmpty: 0
            })
        }
        return result.sort((a, b) => Number(b.internal) - Number(a.internal) || a.name.localeCompare(b.name) || a.id.localeCompare(b.id))
    }

    function statusText(state) {
        switch (state) {
        case "charging": return "Charging"
        case "discharging": return "Discharging"
        case "empty": return "Empty"
        case "charged": return "Fully charged"
        case "pending-charge": return "Charging paused"
        case "pending-discharge": return "Waiting to discharge"
        default: return "Status unavailable"
        }
    }

    function displayName(battery) {
        const brand = String(battery.brand ?? "").trim()
        const name = String(battery.name ?? "Battery-powered device")
        return brand && !name.toLowerCase().includes(brand.toLowerCase()) ? brand + " " + name : name
    }

    function durationText(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0) return ""
        if (seconds < 60) return "less than a minute"
        const minutes = Math.ceil(seconds / 60)
        const hours = Math.floor(minutes / 60)
        const remainder = minutes % 60
        return hours > 0 ? hours + " h" + (remainder > 0 ? " " + remainder + " min" : "") : minutes + " min"
    }

    function timeText(battery) {
        switch (battery.state) {
        case "charging": {
            const time = durationText(battery.timeToFull)
            return time ? "Full in " + time : ""
        }
        case "discharging":
        case "pending-discharge": {
            const time = durationText(battery.timeToEmpty)
            return time ? "Empty in " + time : ""
        }
        default: return ""
        }
    }
}
