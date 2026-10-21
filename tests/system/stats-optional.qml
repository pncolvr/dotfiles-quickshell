pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/config"
import "../../src/services"
import "../../src/modules/system"
import "../../src/ui" as UI

WorkerScope {
    id: root
    property var settings: Config
    property var requests: []
    property int step: 0
    property int ticks: 0
    property bool failed: false
    function check(ok, message) { if (!ok) { failed = true; console.error("STATS OPTIONAL FAIL:", message) } }
    Test.TestCase { id: objects; when: false }
    FileView { id: stopped; path: Qt.resolvedUrl("stopped"); printErrors: false; blockLoading: true }
    QtObject {
        id: network
        property bool active: false
        property real downloadSpeed: 100
        property real uploadSpeed: 10
        property var speedHistory: []
        property var connectedNetworks: []
        property var vpnConnections: []
        function formatSpeed(value) { return String(value) }
    }
    QtObject {
        id: power
        property string profile: "balanced"
        property var availableProfiles: ["balanced"]
        function setProfile(name) { profile = name }
    }
    Component.onCompleted: {
        settings.statsProcessesCommand = resource => {
            root.requests = root.requests.concat([resource])
            return ["bash", Qt.resolvedUrl("collector.sh").toString().replace("file://", ""), resource]
        }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 800
        StatsTooltip { id: panel; networkService: network; powerService: power }
    }
    Timer {
        interval: 80
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 100) { root.check(false,"timed out at step " + root.step); Qt.quit(); return }
            const tabs = objects.findChild(panel,"statsTabs") as UI.TabBar
            switch (root.step) {
            case 0:
                root.check(!root.settings.statsNetworkEnabled && tabs.count === 3, "disabled startup hides only Network")
                root.check(StatsService.active && network.active && root.requests.length === 0, "Overview retains native stats/network without any process collector")
                // An external caller cannot bypass the backend guard.
                StatsService.processResource = "network"
                StatsService.sampleProcesses()
                root.check(root.requests.length === 0, "disabled network cannot launch the collector")
                StatsService.processResource = ""
                panel.currentIndex = 1
                root.step++; break
            case 1:
                if (!StatsService.processes.length) return
                root.check(StatsService.processes[0].name === "Synthetic" && root.requests.includes("cpu"), "CPU still samples with Network disabled")
                panel.currentIndex = 2
                root.step++; break
            case 2:
                if (!root.requests.includes("memory") || !StatsService.processes.length) return
                root.check(StatsService.processes[0].value === 4096, "Memory still samples with Network disabled")
                root.settings.statsNetworkEnabled = true
                root.check(tabs.count === 4, "enabling restores Network")
                panel.currentIndex = 3
                root.step++; break
            case 3:
                if (!StatsService.processesLoading || !root.requests.includes("network")) return
                root.settings.statsNetworkEnabled = false
                root.check(panel.currentIndex === 0 && panel.resource === "" && tabs.count === 3, "disabling selected Network returns to Overview")
                root.step++; break
            case 4:
                if (StatsService.processesLoading) return
                stopped.reload()
                if (!stopped.text().includes("network")) return
                root.check(StatsService.processes.length === 0 && !StatsService.processError, "cancelled late report cannot populate data or errors")
                root.check(network.active && StatsService.active && root.requests.filter(value => value === "network").length === 1, "Overview stays active and network collector does not restart")
                root.settings.statsNetworkEnabled = true
                panel.currentIndex = 3
                root.step++; break
            case 5:
                if (root.requests.filter(value => value === "network").length < 2 || !StatsService.processesLoading) return
                // Toggle twice before the first generation can finish cancellation.
                root.settings.statsNetworkEnabled = false
                root.settings.statsNetworkEnabled = true
                panel.currentIndex = 3
                root.step++; break
            case 6:
                if (root.requests.filter(value => value === "network").length < 3) return
                root.check(!StatsService.processes.length && !StatsService.processError, "rapid re-enable discards cancelled network generation")
                root.settings.statsNetworkEnabled = false
                root.step++; break
            default:
                if (StatsService.processesLoading) return
                root.check(tabs.count === 3 && panel.currentIndex === 0, "final disabled state is Overview")
                if (!root.failed) console.log("PASS: optional Stats Network, independent CPU/Memory/Overview, cancellation, late replies and rapid re-enable")
                stop(); Qt.quit()
            }
        }
    }
}
