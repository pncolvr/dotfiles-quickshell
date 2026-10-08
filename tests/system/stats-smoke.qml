pragma ComponentBehavior: Bound
import QtQuick
import "../../src/theme/ui" as UI
import QtTest as Test
import Quickshell
import "../../src/modules/system"
import "../../src/services"
import "../../src/theme"

Scope {
    id: root
    readonly property StatsTooltip panel: loader.item as StatsTooltip
    property int step: 0
    property bool failed: false
    property real openHeight: 0
    property real groupTotal: 0
    function check(ok, message) { if (!ok) { failed = true; console.error("STATS FAIL:", message) } }
    function find(name) { return mouse.findChild(panel, name) }
    QtObject {
        id: backend
        property bool active: false
        property string processResource: ""
        property real cpu: 38
        property var cores: [10, 20, 30, 40, 50, 60, 70, 80]
        property real temperature: 52
        property real memoryTotal: 32768
        property real memoryUsed: 8192
        property real memoryFree: 12288
        property real memoryAvailable: 24576
        property real memoryCache: 12288
        property real swapTotal: 4096
        property real swapUsed: 128
        property real swapFree: 3968
        property var processes: []
        property string processError: ""
        property bool processesLoading: false
        property int copiedPid: 0
        function copyPid(pid) { copiedPid = pid }
        function sample() {
            processes = Array.from({length: 64}, (_, index) => ({pid: 1000 + index, name: index === 0 ? "Browser" : "worker-" + index,
                value: (64 - index) * (processResource === "memory" ? 1048576 : processResource === "network" ? 1100 : 1),
                down: (64 - index) * 1000, up: (64 - index) * 100, count: index === 0 ? 3 : 1, searchName: index === 0 ? "Browser renderer" : "worker-" + index,
                members: index === 0 ? [40, 20, 4].map((weight, member) => ({pid: 1000 + member,
                    name: member === 0 ? "Browser" : member === 1 ? "renderer" : "worker", label: ["Main process", "Renderer", "GPU process"][member],
                    value: weight * (processResource === "memory" ? 1048576 : processResource === "network" ? 1100 : 1),
                    down: weight * 1000, up: weight * 100})) : []}))
        }
        onProcessResourceChanged: sample()
    }
    QtObject {
        id: network
        property bool active: false
        property real downloadSpeed: 2048000
        property real uploadSpeed: 153600
        property var speedHistory: [{down: 1000, up: 20}, {down: 3000, up: 40}]
        property var connectedNetworks: [{name: "Home", connected: true, downloadSpeed: 1024000, uploadSpeed: 20480}]
        property var vpnConnections: [{name: "Work VPN", active: true}]
        function formatSpeed(value) { return (value / 1024).toFixed(1) + "KB" }
    }
    QtObject {
        id: power
        property string profile: "balanced"
        property var availableProfiles: ["power-saver", "balanced", "performance"]
        function setProfile(name) { if (availableProfiles.includes(name)) profile = name }
    }
    Test.TestCase { id: mouse; when: false }
    FloatingWindow {
        visible: true
        implicitWidth: 600; implicitHeight: 800
        color: Theme.background
        Stats { id: trigger; x: 500; y: 20 }
        Loader { id: loader; x: 20; y: 20; sourceComponent: StatsTooltip { statsService: backend; networkService: network; powerService: power } }
    }
    Timer {
        interval: 150; repeat: true; running: true
        onTriggered: {
            const view = root.panel ? root.find("statsProcessList") as ListView : null
            const search = root.panel ? root.find("statsProcessSearch") as UI.SearchField : null
            if (root.step === 0) {
                root.check(backend.active && network.active && backend.processResource === "" && !search.visible, "Overview opens without process sampling")
                const width = trigger.width
                mouse.mouseMove(trigger, trigger.width / 2, trigger.height / 2)
                root.check(trigger.width === width && Theme.statsIcon.length > 0, "bar icon keeps its fixed width on hover")
                mouse.mouseClick(trigger, trigger.width / 2, trigger.height / 2)
                root.check(TooltipService.pinned && TooltipService.source === trigger, "Stats tooltip pins")
                mouse.mouseClick(trigger, trigger.width / 2, trigger.height / 2)
                root.check(!TooltipService.pinned, "Stats tooltip unpins")
                const saver = root.find("statsPowerProfile-power-saver") as UI.ActionButton
                const balanced = root.find("statsPowerProfile-balanced") as UI.ActionButton
                const performance = root.find("statsPowerProfile-performance") as UI.ActionButton
                root.check(balanced.checked && !saver.checked && !performance.checked, "current profile is highlighted")
                mouse.mouseClick(performance, performance.width / 2, performance.height / 2)
                root.check(power.profile === "performance" && performance.checked, "Performance selects directly without cycling")
                mouse.mouseClick(saver, saver.width / 2, saver.height / 2)
                root.check(power.profile === "power-saver" && saver.checked, "Power saver selects directly")
                mouse.mouseClick(balanced, balanced.width / 2, balanced.height / 2)
                root.check(power.profile === "balanced" && balanced.checked, "Balanced selects directly")
                power.availableProfiles = ["power-saver", "balanced"]
                root.check(!performance.enabled && saver.enabled && balanced.enabled, "unsupported Performance profile is disabled")
                mouse.mouseClick(performance, performance.width / 2, performance.height / 2)
                root.check(power.profile === "balanced", "unavailable profile cannot change the current mode")
                power.availableProfiles = ["power-saver", "balanced", "performance"]
                root.panel.currentIndex = 1
            } else if (root.step === 1) {
                root.check(backend.processResource === "cpu" && search.visible && view.count === 64, "CPU has the full process list")
                root.check((root.find("statsProcessColumns") as Item).visible, "resource table headers are visible")
                root.check((view.itemAtIndex(0) as StatsProcessRow)?.process.pid === 1000 && (view.itemAtIndex(0) as StatsProcessRow)?.process.value === 64, "highest CPU usage is first")
                root.check(root.panel.height <= root.panel.maxPanelHeight && view.contentHeight > view.height, "CPU list stays bounded and scrolls")
                root.openHeight = root.panel.height
                mouse.mouseClick(search, 20, search.height / 2)
                mouse.keyClick(Qt.Key_B)
                root.check(search.activeFocus && search.text === "b", "filter retains focus after the first typed character")
                mouse.keyClick(Qt.Key_R, Qt.ShiftModifier)
                mouse.keyClick(Qt.Key_O)
                mouse.keyClick(Qt.Key_W, Qt.ShiftModifier)
                mouse.keyClick(Qt.Key_S)
                mouse.keyClick(Qt.Key_E, Qt.ShiftModifier)
                mouse.keyClick(Qt.Key_R)
            } else if (root.step === 2) {
                root.check(search.activeFocus && search.text === "browser", "typing continues across filter updates")
                root.check(view.count === 1 && (view.itemAtIndex(0) as StatsProcessRow)?.process.name === "Browser", "case-insensitive name filter")
                root.check(root.panel.height === root.openHeight, "filtering keeps the tooltip surface height stable")
                search.text = "bRoWsEr"
                root.check(search.query === "browser", "name filtering is case insensitive")
                search.text = "renderer"
                root.check(view.count === 1, "filter can find an app through a child process name")
                search.text = "browser"
                backend.sample()
                root.check(search.activeFocus, "live process updates retain input focus")
                const button = mouse.findChild(view.itemAtIndex(0), "statsCopyPid") as UI.ActionButton
                root.check((view.itemAtIndex(0) as StatsProcessRow)?.process.count === 3 && button.hint === "Copy parent PID 1000", "grouped row shows its contributor count and parent PID")
                root.check(button.label === "1000" && button.glyph === Theme.copyIcon, "PID is plain text with copy icon")
                mouse.mouseClick(button, button.width / 2, button.height / 2)
                root.check(backend.copiedPid === 1000, "PID copy button copies the displayed PID")
                root.groupTotal = (view.itemAtIndex(0) as StatsProcessRow).process.value
                const name = mouse.findChild(view.itemAtIndex(0), "statsProcessName") as UI.ColumnText
                root.check((mouse.findChild(view.itemAtIndex(0), "statsProcessCount") as Item).visible && name.text === "Browser" && name.font.bold,
                    "app name remains bold with its process count in a separate badge")
                mouse.mouseClick(name, 5, name.height / 2)
            } else if (root.step === 3) {
                if (Quickshell.env("STATS_TEST_SCREENSHOT")) root.panel.grabToImage(result => result.saveToFile(Quickshell.env("STATS_TEST_SCREENSHOT")))
                root.check(view.count === 4 && (view.itemAtIndex(0) as StatsProcessRow).isExpanded, "expand reveals every contributing process")
                root.check((view.itemAtIndex(0) as StatsProcessRow).process.value === root.groupTotal, "expanded app retains its total")
                const child = view.itemAtIndex(2) as StatsProcessRow
                root.check(child.childProcess && child.process.name === "renderer" && child.process.value === 20 && child.process.pid === 1001,
                    "subprocess shows its own usage and PID in descending usage order")
                const childName = mouse.findChild(child, "statsProcessName") as UI.ColumnText
                root.check(childName.text === "Renderer" && !childName.font.bold && childName.color === Theme.inactive,
                    "child roles are readable with quieter text")
                root.check((view.itemAtIndex(1) as StatsProcessRow).process.label === "Main process",
                    "expanded main process has its own readable label")
                const copy = mouse.findChild(child, "statsCopyPid") as UI.ActionButton
                mouse.mouseClick(copy, copy.width / 2, copy.height / 2)
                root.check(backend.copiedPid === 1001 && copy.hint === "Copy PID 1001", "subprocess copies its own PID")
                backend.sample()
            } else if (root.step === 4) {
                root.check(view.count === 4 && (view.itemAtIndex(0) as StatsProcessRow).isExpanded, "refresh preserves expanded groups")
                search.text = "missing"
            } else if (root.step === 5) {
                root.check(view.count === 0, "filter hides expanded groups")
                search.text = "browser"
            } else if (root.step === 6) {
                root.check(view.count === 4, "restoring the filter preserves expansion")
                const name = mouse.findChild(view.itemAtIndex(0), "statsProcessName") as UI.ColumnText
                mouse.mouseClick(name, 5, name.height / 2)
                const expander = mouse.findChild(view.itemAtIndex(0), "statsExpandProcess") as MouseArea
                root.check(view.count === 1, "collapse removes subprocess rows")
                mouse.mouseClick(expander, 5, expander.height / 2)
                root.panel.currentIndex = 2
            } else if (root.step === 7) {
                root.check(view.count === 1 && !(view.itemAtIndex(0) as StatsProcessRow).isExpanded, "tabs keep separate expansion states")
                root.panel.currentIndex = 1
            } else if (root.step === 8) {
                root.check(view.count === 4 && (view.itemAtIndex(0) as StatsProcessRow).isExpanded, "returning to a tab restores expansion")
                const expander = mouse.findChild(view.itemAtIndex(0), "statsExpandProcess") as MouseArea
                mouse.mouseClick(expander, 5, expander.height / 2)
                search.text = ""
            } else if (root.step === 9) {
                const first = view.itemAtIndex(0) as StatsProcessRow
                mouse.mouseMove(first, first.width - 10, first.height / 2)
                backend.processes = backend.processes.map(row => Object.assign({}, row,
                    {value: row.pid === 1000 ? 2 : row.pid === 1001 ? 1000 : row.value})).sort((a, b) => b.value - a.value)
            } else if (root.step === 10) {
                const first = view.itemAtIndex(0) as StatsProcessRow
                root.check(root.panel.orderingPaused && first.process.pid === 1000 && first.process.value === 2,
                    "hover holds app order while usage continues updating")
                mouse.mouseMove(search, search.width / 2, search.height / 2)
            } else if (root.step === 11) {
                const first = view.itemAtIndex(0) as StatsProcessRow
                root.check(first.process.pid === 1001 && !root.panel.orderingPaused, "leaving the list resumes usage sorting")
                const copy = mouse.findChild(first, "statsCopyPid") as UI.ActionButton
                mouse.mouseClick(copy, copy.width / 2, copy.height / 2)
                mouse.mouseMove(search, search.width / 2, search.height / 2)
                backend.processes = backend.processes.map(row => Object.assign({}, row,
                    {value: row.pid === 1002 ? 2000 : row.value})).sort((a, b) => b.value - a.value)
            } else if (root.step === 12) {
                root.check(root.panel.orderingPaused && (view.itemAtIndex(0) as StatsProcessRow).process.pid === 1001,
                    "clicked PID focus holds ordering after the pointer leaves")
                search.forceActiveFocus()
            } else if (root.step === 13) {
                root.check(!root.panel.orderingPaused && (view.itemAtIndex(0) as StatsProcessRow).process.pid === 1002,
                    "moving focus to the filter resumes sorting")
                backend.sample()
            } else if (root.step === 14) {
                const first = view.itemAtIndex(0) as StatsProcessRow
                const name = mouse.findChild(first, "statsProcessName") as UI.ColumnText
                mouse.mouseClick(name, 5, name.height / 2)
                mouse.mouseMove(search, search.width / 2, search.height / 2)
                backend.processes = backend.processes.map(row => row.pid !== 1000 ? row : Object.assign({}, row, {value: 56,
                    members: row.members.map(member => Object.assign({}, member,
                        {value: member.pid === 1000 ? 1 : member.pid === 1001 ? 50 : 5})).sort((a, b) => b.value - a.value)
                })).sort((a, b) => b.value - a.value)
            } else if (root.step === 15) {
                root.check(root.panel.orderingPaused && (view.itemAtIndex(0) as StatsProcessRow).process.pid === 1000
                    && (view.itemAtIndex(0) as StatsProcessRow).process.value === 56, "expanded app remains in place outside hover")
                root.check((view.itemAtIndex(1) as StatsProcessRow).process.pid === 1000
                    && (view.itemAtIndex(1) as StatsProcessRow).process.value === 1
                    && (view.itemAtIndex(2) as StatsProcessRow).process.pid === 1001
                    && (view.itemAtIndex(2) as StatsProcessRow).process.value === 50,
                    "expanded subprocesses retain their positions as their individual usage changes")
                const name = mouse.findChild(view.itemAtIndex(0), "statsProcessName") as UI.ColumnText
                mouse.mouseClick(name, 5, name.height / 2)
                backend.sample()
                mouse.mouseMove(search, search.width / 2, search.height / 2)
            } else if (root.step === 16) {
                view.positionViewAtIndex(63, ListView.End)
            } else if (root.step === 17) {
                root.check(view.atYEnd && view.itemAtIndex(63) !== null, "last process is reachable")
                backend.sample()
            } else if (root.step === 18) {
                root.check(view.atYEnd, "live refresh preserves scroll position")
                root.panel.currentIndex = 2
            } else if (root.step === 19) {
                root.check(backend.processResource === "memory" && view.count === 64 && (view.itemAtIndex(0) as StatsProcessRow)?.process.value === 64 * 1048576, "Memory shows independently sorted usage")
                search.text = "missing"
            } else if (root.step === 20) {
                root.check(view.count === 0, "filter can hide all rows")
                search.text = ""
                root.panel.currentIndex = 3
            } else if (root.step === 21) {
                root.check(backend.processResource === "network" && view.count === 64, "Network lists all sampled processes")
                backend.processes = [{pid: 1000, name: "Browser", count: 1, value: 22, down: 20, up: 2,
                    members: [{pid: 1001, name: "renderer", label: "Renderer", value: 22, down: 20, up: 2}]}]
            } else if (root.step === 22) {
                const group = view.itemAtIndex(0) as StatsProcessRow
                root.check(group.canExpand, "single active network child remains expandable under its app parent")
                const expander = mouse.findChild(group, "statsExpandProcess") as MouseArea
                mouse.mouseClick(expander, 5, expander.height / 2)
            } else if (root.step === 23) {
                const child = view.itemAtIndex(1) as StatsProcessRow
                if (Quickshell.env("STATS_TEST_NETWORK_SCREENSHOT")) root.panel.grabToImage(result => result.saveToFile(Quickshell.env("STATS_TEST_NETWORK_SCREENSHOT")))
                const download = mouse.findChild(child, "statsProcessDownload") as UI.ColumnText
                const upload = mouse.findChild(child, "statsProcessUpload") as UI.ColumnText
                root.check(download.width === Theme.statsTrafficWidth && upload.width === Theme.statsTrafficWidth
                    && download.text.endsWith("/s") && upload.text.endsWith("/s"), "network rates occupy separate fixed-width columns with units")
                root.check(view.count === 2 && child.childProcess && child.process.pid === 1001 && child.process.down === 20,
                    "network expansion exposes the contributing child's traffic and actual PID")
                const copy = mouse.findChild(child, "statsCopyPid") as UI.ActionButton
                mouse.mouseClick(copy, copy.width / 2, copy.height / 2)
                root.check(backend.copiedPid === 1001, "network subprocess PID copies independently from its parent")
            } else if (root.step === 24) {
                backend.processes = [{pid: 0, name: "unresolved", value: 0, down: 0, up: 0}]
            } else if (root.step === 25) {
                const button = mouse.findChild(view.itemAtIndex(0), "statsCopyPid") as UI.ActionButton
                root.check(!button.enabled && button.label === "—", "ambiguous socket owner never copies a guessed PID")
                root.panel.currentIndex = 0
            } else if (root.step === 26) {
                root.check(backend.processResource === "" && view.count === 0, "Overview stops process sampling")
                loader.active = false
            } else if (root.step === 27) {
                root.check(!backend.active && !network.active && backend.processResource === "", "closing Stats stops collectors")
                console.log(root.failed ? "STATS FAIL: panel" : "PASS: Stats tabs, fixed bar icon, pinning, full process lists, expansion, stable hover/focus ordering, child usage, filtering, scrolling and PID copy")
                Qt.quit(); return
            }
            root.step++
        }
    }
}
