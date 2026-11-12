pragma Singleton

import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import "../../config"

// Mounted block-device filesystems with space usage (lsblk) and read/write
// rates (/proc/diskstats). Collection runs only while `active` is set.
Singleton {
    id: root
    property bool active: false
    // [{key, name, mount, mounts, device, fstype, model, efi, size, used, avail, read, write}]
    property var disks: []
    property real readSpeed: 0
    property real writeSpeed: 0
    // Space across every filesystem except EFI system partitions.
    property real totalSize: 0
    property real totalUsed: 0
    property real totalAvail: 0
    property string error: ""
    property bool loaded: false
    readonly property bool loading: active && !loaded && !error
    property var filesystems: []
    property var rates: ({})
    property var previousCounters: ({})
    property real previousTime: 0

    // Binary units, one decimal below 10 so small values stay meaningful.
    function formatBytes(bytes) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
        let value = Math.max(0, Number(bytes) || 0)
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit++ }
        return (unit === 0 || value >= 10 ? Math.round(value) : value.toFixed(1)) + " " + units[unit]
    }
    function formatRate(bytesPerSecond) { return formatBytes(bytesPerSecond) + "/s" }
    function openMount(path) {
        if (path) Quickshell.execDetached(Config.directoryOpenCommand.concat([path]))
    }
    // EFI system partitions: the ESP type GUID, or FAT mounted at a conventional ESP path.
    function isEfi(node, mounts) {
        if (String(node.parttype || "").toLowerCase() === "c12a7328-f81f-11d2-ba4b-00a0c93ec93b") return true
        return /^v?fat/i.test(node.fstype || "") && mounts.some(path => ["/boot", "/efi", "/boot/efi"].includes(path))
    }

    function applyBlockDevices(report) {
        const devices = report?.blockdevices
        if (!Array.isArray(devices)) return false
        const found = new Map()
        const visit = (node, model) => {
            const inherited = node.model || model || ""
            const mounts = (node.mountpoints || [node.mountpoint]).filter(path => typeof path === "string" && path.startsWith("/"))
                .sort((left, right) => left.length - right.length || left.localeCompare(right))
            const size = Number(node.fssize)
            const kname = node.kname || node.name
            if (mounts.length && size > 0 && kname && !found.has(kname)) {
                const mount = mounts[0]
                const used = Math.max(0, Number(node.fsused) || 0)
                found.set(kname, {key: kname, kname, mount, mounts, size, used,
                    avail: Number.isFinite(Number(node.fsavail)) && node.fsavail !== null ? Number(node.fsavail) : Math.max(0, size - used),
                    name: node.label || (mount === "/" ? "/" : mount.slice(mount.lastIndexOf("/") + 1)),
                    device: "/dev/" + (node.name || kname), fstype: node.fstype || "", model: inherited.trim(),
                    efi: isEfi(node, mounts)})
            }
            for (const child of node.children || []) visit(child, inherited)
        }
        for (const device of devices) visit(device, "")
        filesystems = Array.from(found.values())
            .sort((left, right) => (left.mount === "/" ? -1 : right.mount === "/" ? 1 : left.mount.localeCompare(right.mount)))
        error = ""
        loaded = true
        rebuild()
        return true
    }
    // Fields after the name: reads, merged, sectors read, ms, writes, merged, sectors written.
    // Sectors are always 512 bytes here, regardless of the device's block size.
    function applyDiskStats(text, now = Date.now()) {
        const counters = {}
        for (const line of text.trim().split("\n")) {
            const fields = line.trim().split(/\s+/)
            if (fields.length < 10) continue
            const read = Number(fields[5]) * 512
            const written = Number(fields[9]) * 512
            if (Number.isFinite(read) && Number.isFinite(written)) counters[fields[2]] = {read, written}
        }
        const elapsed = (now - previousTime) / 1000
        const next = {}
        for (const name in counters) {
            const previous = previousCounters[name]
            next[name] = previous && elapsed > 0 ? {
                read: Math.max(0, counters[name].read - previous.read) / elapsed,
                write: Math.max(0, counters[name].written - previous.written) / elapsed
            } : {read: 0, write: 0}
        }
        previousCounters = counters
        previousTime = now
        rates = next
        rebuild()
    }
    function rebuild() {
        const rows = filesystems.map(filesystem => Object.assign({}, filesystem,
            {read: rates[filesystem.kname]?.read ?? 0, write: rates[filesystem.kname]?.write ?? 0}))
        disks = rows
        readSpeed = rows.reduce((sum, row) => sum + row.read, 0)
        writeSpeed = rows.reduce((sum, row) => sum + row.write, 0)
        const storage = rows.filter(row => !row.efi)
        totalSize = storage.reduce((sum, row) => sum + row.size, 0)
        totalUsed = storage.reduce((sum, row) => sum + row.used, 0)
        totalAvail = storage.reduce((sum, row) => sum + row.avail, 0)
    }
    onActiveChanged: {
        if (active) { previousCounters = ({}); previousTime = 0; return }
        blockDevices.running = false
        rates = ({})
        rebuild()
    }
    Timer {
        interval: Config.statsInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: diskStatsFile.reload()
    }
    Timer {
        interval: Config.statsDisksInterval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!blockDevices.running) blockDevices.running = true
    }
    FileView {
        id: diskStatsFile
        path: Config.statsProcRoot + "/diskstats"
        preload: root.active
        printErrors: false
        onLoaded: if (root.active) root.applyDiskStats(text())
    }
    Process {
        id: blockDevices
        command: Config.statsDisksCommand
        stdout: StdioCollector { id: blockDevicesOutput; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (!root.active) return
            let report
            try { report = JSON.parse(blockDevicesOutput.text) } catch (_) { report = null }
            if (exitCode !== 0 || exitStatus !== 0 || !root.applyBlockDevices(report))
                root.error = Translations.text("stats.disks.error")
        }
        // qmllint enable signal-handler-parameters
    }
}
