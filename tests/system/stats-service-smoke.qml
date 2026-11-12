import QtQuick
import "../../src/services"
import "../../src/i18n"
WorkerScope {
    id: root
    property bool failed: false
    function check(ok, message) { if (!ok) { failed = true; console.error("STATS FAIL:", message) } }
    Timer {
        interval: 0
        running: Translations.messages["stats.processes.main"] !== undefined
        onTriggered: {
            StatsService.applyCpu("cpu 100 0 0 100 0 0 0 0\ncpu0 100 0 0 100 0 0 0 0")
            StatsService.applyCpu("cpu 150 0 0 150 0 0 0 0\ncpu0 150 0 0 150 0 0 0 0")
            root.check(StatsService.cpu === 50 && StatsService.cores[0] === 50, "native stat file deltas")
            StatsService.applyMemory("MemTotal: 8192 kB\nMemFree: 1024 kB\nMemAvailable: 3072 kB\nCached: 2048 kB\nSReclaimable: 1024 kB\nShmem: 512 kB\nSwapTotal: 4096 kB\nSwapFree: 1024 kB")
            root.check(StatsService.memoryUsed === 5 && StatsService.memoryCache === 2.5 && StatsService.swapUsed === 3, "native meminfo units and available memory")
            StatsService.processResource = "cpu"
            const report = {timestamp: 1, clockTicks: 100, processes: [{pid: 1, name: "small", ticks: 100, start: "1", memory: 2}, {pid: 2, name: "large", ticks: 100, start: "1", memory: 1}]}
            StatsService.applyProcesses(report)
            report.timestamp = 3; report.processes[0].ticks = 150; report.processes[1].ticks = 300
            StatsService.applyProcesses(report)
            root.check(StatsService.processes[0].pid === 2 && StatsService.processes[0].value === 100 && StatsService.processes[1].value === 25, "CPU uses elapsed time and sorts descending")
            report.timestamp = 4; report.processes[1].start = "2"; report.processes[1].ticks = 10000
            StatsService.applyProcesses(report)
            root.check(StatsService.processes.find(row => row.pid === 2).value === 0, "reused PID starts a new baseline")
            StatsService.processResource = "memory"
            StatsService.applyProcesses(report)
            root.check(StatsService.processes[0].pid === 1 && StatsService.processes[0].value === 2, "memory sorts by RSS")
            StatsService.processResource = "network"
            StatsService.applyProcesses({timestamp: 5, clockTicks: 100, processes: [{pid: 1, name: "a", down: 5, up: 10}, {pid: 2, name: "b", down: 20, up: 2}]})
            root.check(StatsService.processes[0].pid === 2 && StatsService.processes[0].value === 22, "network sorts combined traffic")
            // Different helper names and independent instances share one app total.
            StatsService.processResource = "cpu"
            const grouped = {timestamp: 10, clockTicks: 100, processes: [
                {pid: 10, name: "Discord", appPid: 10, appName: "Discord", ticks: 100, start: "1", memory: 100},
                {pid: 11, name: "renderer", role: "Renderer", appPid: 10, appName: "Discord", ticks: 100, start: "1", memory: 200},
                {pid: 20, name: "Discord", appPid: 20, appName: "Discord", ticks: 100, start: "1", memory: 300},
                {pid: 30, name: "QtWebEngineProc", appPid: 29, appName: "qutebrowser", ticks: 100, start: "1", memory: 400}]}
            StatsService.applyProcesses(grouped)
            grouped.timestamp = 11
            grouped.processes.forEach(row => { row.ticks += 100 })
            StatsService.applyProcesses(grouped)
            root.check(StatsService.processes.length === 2 && StatsService.processes[0].name === "Discord"
                && StatsService.processes[0].value === 300 && StatsService.processes[0].count === 3 && StatsService.processes[0].pid === 10,
                "CPU adds individual process deltas and keeps the app parent PID")
            root.check(StatsService.processes[0].members.length === 3 && StatsService.processes[0].members.reduce((sum, member) => sum + member.value, 0) === 300, "CPU group retains the individual process values")
            StatsService.processResource = "memory"
            StatsService.applyProcesses(grouped)
            root.check(StatsService.processes[0].value === 600 && StatsService.processes[0].searchName.includes("renderer"),
                "RSS adds across helper names and instances, retaining child names for filtering")
            root.check(StatsService.processes[0].members.find(member => member.pid === 11).label === "Renderer"
                && StatsService.processes[0].members.find(member => member.pid === 10).label === "Main process",
                "detected helper roles and main-process fallback survive grouping")
            root.check(StatsService.processes[0].members[0].pid === 20 && StatsService.processes[0].members[0].value === 300, "subprocesses are sorted by the selected resource")
            StatsService.processResource = "network"
            StatsService.applyProcesses({timestamp: 12, clockTicks: 100, processes: [
                {pid: 10, name: "Discord", appPid: 10, appName: "Discord", down: 4, up: 6},
                {pid: 11, name: "renderer", appPid: 10, appName: "Discord", down: 20, up: 30},
                {pid: 30, name: "QtWebEngineProc", appPid: 29, appName: "qutebrowser", down: 10, up: 10}]})
            root.check(StatsService.processes[0].value === 60 && StatsService.processes[0].down === 24
                && StatsService.processes[0].up === 36 && StatsService.processes[0].pid === 10, "network adds app traffic before sorting")
            // Disks: nested lsblk tree, duplicate mounts, unmounted/swap entries and diskstats deltas.
            root.check(DiskService.applyBlockDevices({blockdevices: [
                {name: "nvme0n1", kname: "nvme0n1", type: "disk", model: "Fast SSD  ", mountpoints: [null], children: [
                    {name: "nvme0n1p1", kname: "nvme0n1p1", type: "part", fstype: "vfat", fssize: 314572800, fsused: 1048576, fsavail: 313524224, mountpoints: ["/boot/efi"]},
                    {name: "nvme0n1p2", kname: "nvme0n1p2", type: "part", fstype: "btrfs", fssize: 1000, fsused: 900, fsavail: 80, mountpoints: ["/home", "/"]},
                    {name: "nvme0n1p3", kname: "nvme0n1p3", type: "part", fstype: "swap", fssize: null, mountpoints: ["[SWAP]"]}]},
                {name: "sda", kname: "sda", type: "disk", model: "Archive", mountpoints: [], children: [
                    {name: "sda1", kname: "sda1", type: "part", fstype: "ext4", label: "Trantor", fssize: 2000, fsused: 500, fsavail: 1400, mountpoints: ["/mnt/Trantor"]}]}]}),
                "lsblk report parses")
            const mounted = DiskService.disks
            root.check(mounted.length === 3 && mounted[0].mount === "/" && mounted[0].mounts.length === 2 && mounted[0].name === "/"
                && mounted[0].model === "Fast SSD" && mounted[0].avail === 80, "root first, one entry per device, inherited model")
            root.check(mounted[1].efi && !mounted[0].efi && !mounted[2].efi, "vfat at /boot/efi is flagged as EFI")
            root.check(mounted[1].name === "efi" && mounted[2].name === "Trantor" && mounted[2].device === "/dev/sda1",
                "label or mount basename names each filesystem")
            root.check(DiskService.totalSize === 3000 && DiskService.totalUsed === 1400 && DiskService.totalAvail === 1480,
                "global storage totals skip EFI partitions")
            root.check(!DiskService.applyBlockDevices({}), "malformed lsblk report is rejected")
            DiskService.applyDiskStats("259 2 nvme0n1p2 10 0 2048 0 20 0 4096 0 0 0 0\n8 1 sda1 1 0 0 0 1 0 0 0 0 0 0", 1000)
            root.check(DiskService.readSpeed === 0 && DiskService.writeSpeed === 0, "first diskstats sample sets the baseline")
            DiskService.applyDiskStats("259 2 nvme0n1p2 10 0 4096 0 20 0 8192 0 0 0 0\n8 1 sda1 1 0 0 0 1 0 2048 0 0 0 0", 3000)
            const system = DiskService.disks.find(disk => disk.kname === "nvme0n1p2")
            root.check(system.read === 524288 && system.write === 1048576 && DiskService.writeSpeed === 1048576 + 524288,
                "diskstats sectors become bytes per second")
            root.check(DiskService.formatBytes(0) === "0 B" && DiskService.formatBytes(1536) === "1.5 KiB"
                && DiskService.formatBytes(800 * 1073741824) === "800 GiB" && DiskService.formatRate(1572864) === "1.5 MiB/s"
                && DiskService.formatBytes(2 * 1099511627776) === "2.0 TiB", "human-readable binary units")
            StatsService.copyPid(2345, success => {
                root.check(success, "PID clipboard write completes")
                console.log(root.failed ? "STATS FAIL: collectors" : "PASS: Stats native file parsing, process deltas, PID reuse, resource sorting, disk parsing/rates and clipboard command")
                Qt.quit()
            })
        }
    }
}
