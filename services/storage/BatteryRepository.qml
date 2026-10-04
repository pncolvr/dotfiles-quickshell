pragma Singleton

import Quickshell
import "../"

Singleton {
    function receiverSnapshot() {
        const rows = DbService.read("SELECT payload_json FROM battery_receivers ORDER BY device_id")
        if (rows === null) return []
        const devices = []
        for (const row of rows) {
            try {
                const device = JSON.parse(row.payload_json)
                if (device && typeof device.id === "string") devices.push(device)
            } catch (error) {
                console.warn("Ignoring an invalid cached receiver battery")
            }
        }
        return devices
    }

    function saveReceiverSnapshot(devices) {
        if (!Array.isArray(devices)) return false
        return DbService.write(tx => {
            tx.executeSql("DELETE FROM battery_receivers")
            for (const device of devices)
                tx.executeSql("INSERT INTO battery_receivers (device_id, payload_json, updated_at) VALUES (?, ?, ?)", [device.id, JSON.stringify(device), Date.now()])
        })
    }
}
