pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../../theme"
import "../../../config"
import "../../../ui" as UI
import "../../../services"
import ".."

Column {
    id: root
    property var statsService: StatsService
    property var networkService: NetworkService
    property var powerService: PowerProfileService
    property alias currentIndex: tabs.currentIndex
    readonly property bool networkEnabled: Config.statsNetworkEnabled
    onNetworkEnabledChanged: if (!networkEnabled && currentIndex >= 3) currentIndex = 0
    property var expandedGroups: ({})
    property int applicationCount: 0
    property var processOrders: ({})
    readonly property bool orderingPaused: processHover.hovered
        || view.contentItem.children.some(item => (item as StatsProcessRow)?.pidFocused === true)
        || Object.keys(expandedGroups).some(key => key.startsWith(resource + ":") && expandedGroups[key] === true)
    onOrderingPausedChanged: if (!orderingPaused) Qt.callLater(root.updateProcesses)
    readonly property string resource: (networkEnabled ? ["", "cpu", "memory", "network"] : ["", "cpu", "memory"])[tabs.currentIndex] || ""
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxPanelHeight: Math.max(0, Math.min((monitor?.height ?? 1080) * Theme.statsTooltipMaxHeightRatio,
        (monitor?.height ?? 1080) - Theme.barHeight - Theme.tooltipPaddingHeight * 2))
    width: Math.min(Theme.statsTooltipWidth, (monitor?.width ?? Theme.statsTooltipWidth + Theme.tooltipPaddingWidth * 2) - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.controlSpacing
    Component.onCompleted: {
        statsService.active = true
        networkService.active = true
        statsService.processResource = resource
        updateProcesses()
    }
    Component.onDestruction: {
        statsService.processResource = ""
        statsService.active = false
        networkService.active = false
    }
    function toggleGroup(name) {
        const key = resource + ":" + name.toLowerCase()
        expandedGroups = Object.assign({}, expandedGroups, {[key]: !expandedGroups[key]})
        updateProcesses()
    }
    function orderedProcesses(items, scope, keyFor) {
        const keys = items.map(keyFor)
        const previous = processOrders[scope] || []
        const order = orderingPaused
            ? previous.filter(key => keys.includes(key)).concat(keys.filter(key => !previous.includes(key))) : keys
        processOrders[scope] = order
        const byKey = new Map(items.map(item => [keyFor(item), item]))
        return order.map(key => byKey.get(key))
    }
    function updateProcesses(preservePosition = true) {
        const offset = preservePosition ? view.contentY : view.originY
        const query = search?.query ?? ""
        const groups = resource ? orderedProcesses(statsService.processes, resource + ":apps", row => row.name.toLowerCase())
            .filter(row => (row.searchName || row.name).toLowerCase().includes(query)) : []
        applicationCount = groups.length
        const rows = []
        for (const group of groups) {
            const key = resource + ":" + group.name.toLowerCase()
            const expandable = (group.members?.length ?? 0) > 1 || (group.members || []).some(member => member.pid !== group.pid)
            const expanded = expandable && expandedGroups[key] === true
            rows.push({key, pid: group.pid, name: group.name, label: group.name, value: group.value, down: group.down || 0, up: group.up || 0,
                count: group.count || 1, isChild: false, expandable, expanded})
            if (expanded) for (const member of orderedProcesses(group.members, key, member => member.pid + ":" + member.name)) {
                rows.push({key: key + ":" + member.pid + ":" + member.name, pid: member.pid, name: member.name,
                    label: member.label || (member.pid === group.pid ? Translations.text("stats.processes.main") : member.name),
                    value: member.value, down: member.down || 0, up: member.up || 0, count: 1, isChild: true, expandable: false, expanded: false})
            }
        }
        const keys = rows.map(row => row.key)
        for (let index = processModel.count - 1; index >= 0; index--)
            if (!keys.includes(processModel.get(index).key)) processModel.remove(index)
        for (let index = 0; index < rows.length; index++) {
            let oldIndex = -1
            for (let item = index; item < processModel.count; item++) {
                if (processModel.get(item).key === keys[index]) { oldIndex = item; break }
            }
            const row = rows[index]
            if (oldIndex === -1) processModel.insert(index, row)
            else { if (oldIndex !== index) processModel.move(oldIndex, index, 1); processModel.set(index, row) }
        }
        Qt.callLater(() => {
            if (!view) return // A closing panel can unload before this queued layout.
            view.forceLayout()
            if (preservePosition) view.contentY = Math.max(view.originY, Math.min(offset, view.originY + Math.max(0, view.contentHeight - view.height)))
            else view.positionViewAtBeginning()
        })
    }
    onResourceChanged: { statsService.processResource = resource; updateProcesses(false) }
    Connections {
        target: root.statsService
        function onProcessesChanged() { root.updateProcesses() }
    }
    ListModel { id: processModel }
    Column {
        id: heading
        width: parent.width
        spacing: root.spacing
        UI.TabBar {
            id: tabs
            objectName: "statsTabs"
            width: parent.width
            labels: [Translations.text("stats.tabs.overview"), "CPU", Translations.text("stats.tabs.memory")]
                .concat(root.networkEnabled ? [Translations.text("stats.tabs.network")] : [])
        }
        Flickable {
            id: summaryView
            property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: summaryView }
            width: root.width + Theme.scrollbarGutter
            height: Math.min(contentHeight, root.maxPanelHeight * 0.5)
            contentHeight: summary.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Loader {
                id: summary
                width: root.width
                sourceComponent: root.resource === "cpu" ? cpu : root.resource === "memory" ? memory : root.resource === "network" ? network : overview
            }
            QC.ScrollBar.vertical: UI.ScrollBar {}
        }
        Rectangle {
            visible: root.resource.length > 0
            width: parent.width
            height: 1
            color: Theme.empty
        }
        UI.ColumnText {
            width: parent.width
            visible: root.resource.length > 0
            text: root.statsService.processError || (!processModel.count ? root.statsService.processesLoading ? Translations.text("stats.processes.loading")
                : Translations.text(search.query ? "stats.processes.emptyFiltered" : "stats.processes.empty") : Translations.text("stats.processes.count",[root.applicationCount]))
            color: root.statsService.processError ? Theme.warning : Theme.inactive
            wrapMode: Text.Wrap
        }
        UI.SearchField {
            id: search
            objectName: "statsProcessSearch"
            width: parent.width
            visible: root.resource.length > 0
            placeholderText: Translations.text("stats.processes.searchPlaceholder")
            onQueryChanged: root.updateProcesses(false)
        }
        Item {
            objectName: "statsProcessColumns"
            visible: root.resource.length > 0
            width: parent.width
            height: Theme.controlHeight * 0.6
            UI.ColumnText {
                x: Theme.fontSize + Theme.controlSpacing
                text: Translations.text("stats.processes.application")
                color: Theme.inactive
                font.pixelSize: Theme.fontSize - 1
                font.styleName: ""
                font.bold: false
                font.weight: Font.Normal
            }
            UI.ColumnText {
                anchors.right: usageColumns.left
                anchors.rightMargin: Theme.controlSpacing
                width: Theme.statsPidWidth
                horizontalAlignment: Text.AlignHCenter
                text: Translations.text("stats.processes.pidLabel")
                color: Theme.inactive
                font.pixelSize: Theme.fontSize - 1
                font.styleName: ""
                font.bold: false
                font.weight: Font.Normal
            }
            Row {
                id: usageColumns
                anchors.right: parent.right
                spacing: Theme.controlSpacing
                Repeater {
                    model: root.resource === "network" ? ["Download", "Upload"] : [root.resource === "cpu" ? "CPU" : "Memory"]
                    UI.ColumnText {
                        required property string modelData
                        width: root.resource === "network" ? Theme.statsTrafficWidth : Theme.statsValueWidth
                        horizontalAlignment: Text.AlignRight
                        text: ({Download:Translations.text("stats.network.download"),Upload:Translations.text("stats.network.upload"),Memory:Translations.text("stats.tabs.memory")})[modelData] ?? modelData
                        color: Theme.inactive
                        font.pixelSize: Theme.fontSize - 1
                        font.styleName: ""
                        font.bold: false
                        font.weight: Font.Normal
                    }
                }
            }
        }
        Rectangle { width: parent.width; height: root.resource ? 1 : 0; color: Theme.empty }
    }
    ListView {
        id: view
        property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: view }
        objectName: "statsProcessList"
        width: root.width + Theme.scrollbarGutter
        height: root.resource ? Math.max(0, root.maxPanelHeight - heading.height - root.spacing) : 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        model: processModel
        spacing: Theme.statsProcessRowSpacing
        HoverHandler { id: processHover }
        delegate: StatsProcessRow {
            required property int pid
            required property string name
            required property string label
            required property real value
            required property real down
            required property real up
            required property int count
            required property bool isChild
            required property bool expandable
            required property bool expanded
            width: root.width
            process: ({pid, name, label, value, down, up, count})
            childProcess: isChild
            canExpand: expandable
            isExpanded: expanded
            onToggleExpanded: root.toggleGroup(name)
            resource: root.resource
            statsService: root.statsService
            networkService: root.networkService
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
    }
    Component { id: overview; StatsOverview { width: root.width; statsService: root.statsService; networkService: root.networkService; powerService: root.powerService } }
    Component { id: cpu; CpuTooltip { width: root.width; statsService: root.statsService } }
    Component { id: memory; MemoryTooltip { width: root.width; statsService: root.statsService } }
    Component { id: network; NetworkTooltip { width: root.width; networkService: root.networkService } }
}
