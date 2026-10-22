pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/ui" as UI
import "../../src/theme"
import "../../src/config"
import "../../src/services"
import "../../src/modules/launcher" as Launcher
import "../../src/services/launcher" as LauncherServices
import "../../src/modules/status"
import "../../src/services/webapps/WebappEntries.mjs" as Webapps
import "../../src/services/remotes/RemoteEntries.mjs" as Remotes
import "../../src/services/n8n/N8nEntries.mjs" as N8n

WorkerScope {
    id: root
    property bool failed: false
    property bool showWork: false
    property bool showList: false
    property int formType: 0
    property bool expanded: false
    property int openingSignals: 0
    property var settings: Config
    property var audio: AudioService
    function check(ok, message) { if (!ok) { failed = true; console.error("MANAGE FAIL:",message) } }
    function find(name, item = window.contentItem) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const found = find(name,child)
            if (found) return found
        }
        return null
    }
    function checkPickerAlignment(panel) {
        const search = find("pickerSearch", panel)
        const list = find("pickerList", panel) as UI.PickerList
        const row = list.currentItem
        const left = search.mapToItem(panel, 0, 0).x
        const right = left + search.width
        check(!!row && Math.abs(row.width - search.width) < 0.1
            && Math.abs(row.mapToItem(panel, 0, 0).x - left) < 0.1,
            "launcher rows have the same width and left edge as the search input")
        check(Math.abs(left - Theme.scrollbarGutter) < 0.1 && Math.abs(panel.width - right - left) < 0.1,
            "launcher header and rows share balanced outer padding")
        const bar = list.children.find(item => item instanceof UI.ScrollBar && item.orientation === Qt.Vertical)
        const center = bar.mapToItem(panel, bar.width / 2, 0).x
        check(Math.abs(center - (right + panel.width) / 2) < 0.1 && bar.mapToItem(panel, 0, 0).x >= right,
            "launcher scrollbar stays centered beside the rows in the outer padding")
    }
    function preview(name) {
        const directory = Quickshell.env("MANAGE_PREVIEWS")
        if (directory) events.grabImage(window.contentItem).save(directory + "/" + name + ".png")
    }
    Test.TestCase { id: events; when: false }
    Connections { target: PickerService; function onOpened() { root.openingSignals++ } }
    QtObject {
        id: filterRepository
        property var entries: Array.from({length:20}, (_,i) => ({id:String(i), name:"Filter row " + i,
            url:"https://example.test/" + i, enabled:true, category:i ? "work" : "personal"}))
        property string error: ""
        function reload() { return true }
    }
    LauncherServices.ManagedCollectionService {
        id: filterService
        repository: filterRepository
        pickerMode: PickerService.Mode.Webapps
        collectionName: "Synthetic filters"
        itemForEntry: entry => ({id:entry.id,title:entry.name,subtitle:entry.url,result:entry.id})
    }
    Launcher.WebappPickerPanel { id: filterPanel; visible: false; service: filterService }
    QtObject {
        id: rulesBackend
        property var rules: ({workDirectories:["/fixture/work"],processes:["fixture-process"]})
        property string rulesError: ""
        function saveRules(value) { rules = value; return true }
    }
    UI.PanelMotion {
        id: motion
        requested: true
        targetWidth: root.expanded ? Theme.manageWidth : Theme.pickerWidth
        targetHeight: 600
    }
    FloatingWindow {
        id: window
        color: Theme.tooltipBackground
        visible: true
        implicitWidth: Theme.manageWidth
        implicitHeight: Theme.manageHeight
        Column {
            anchors.fill: parent
            visible: !root.showWork && !root.showList
            UI.TabBar { width: parent.width; labels: ["Entries","Manage"]; currentIndex: 1 }
            UI.ManagementView {
                id: view
                width: parent.width
                height: parent.height - y
                showCategory: true
                filterEnabled: true
                browserOptions: [{name:"one",description:"Browser one"},{name:"two",description:"Browser two"}]
                typeOptions: [{name:"remote",description:"SSH"},{name:"vm",description:"VM"}]
                filterAvailability: true
                hints: "Ctrl+M: Manage"
                searchPlaceholder: "Search entries"
                entries: Array.from({length:30},(_,i) => ({id:String(i),title:"Entry " + String(i).padStart(2,"0"),subtitle:i ? "/fixture/entry/" + i : "",
                    category:i % 3 ? "work" : "personal",enabled:i % 3 !== 1,browser:i % 3 === 1 ? "two" : "one",
                    type:i % 3 ? "vm" : "remote",availability:["available","unavailable","unchecked"][i % 3]}))
                onEditRequested: editing = true
                detailContent: [
                    UI.LabeledField { width: parent.width; visible: !view.editing; readOnly: true; label: "Folder"; text: view.selectedEntry?.subtitle ?? "" },
                    Launcher.WebappForm { id: webappForm; width: parent.width; visible: view.editing && root.formType === 0 },
                    Launcher.RemoteForm { id: remoteForm; width: parent.width; visible: view.editing && root.formType === 1 },
                    Launcher.N8nInstanceForm { id: n8nForm; width: parent.width; visible: view.editing && root.formType === 2 }
                ]
                actionContent: [
                    UI.ActionButton { visible: !view.editing && !!view.selectedEntry; glyph: Theme.editIcon; onClicked: view.editing = true },
                    UI.ActionButton { visible: !view.editing && !!view.selectedEntry; glyph: Theme.deleteIcon; fillColor: Theme.urgent },
                    UI.EditorActions { visible: view.editing; onCancelled: view.editing = false }
                ]
            }
        }
        Launcher.PickerPanelBase { id: plainList; width: parent.width; height: parent.height; visible: root.showList }
        StatusRulesEditor { id: work; width: Theme.statusTooltipWidth; visible: root.showWork; statusService: rulesBackend }
    }
    Timer {
        interval: 300; running: true
        onTriggered: {
            root.check(view.selectedId === "0", "first entry selected")
            root.check(view.listView.itemAtIndex(0).height === view.listView.itemAtIndex(1).height, "rows reserve the same height with and without a subtitle")
            const row = view.listView.itemAtIndex(1) as QC.ItemDelegate
            const title = row.contentItem.children[0]
            const subtitle = row.contentItem.children[1]
            const topPadding = title.mapToItem(row,0,0).y
            const bottomPadding = row.height - subtitle.mapToItem(row,0,subtitle.height).y
            root.check(topPadding >= Theme.pickerRowPadding && bottomPadding >= Theme.pickerRowPadding
                && Math.abs(topPadding - bottomPadding) < 1,
                "two-line row background contains both lines with balanced vertical padding")
            root.check(view.listView.contentHeight > view.listView.height, "list has independent bounded scrolling")
            root.preview("details")
            root.find("managementCategory").selected("work")
            root.find("managementFilter-enabled").selected("true")
            root.find("managementFilter-browser").selected("one")
            root.find("managementFilter-type").selected("vm")
            root.find("managementFilter-availability").selected("unchecked")
            view.query = "Entry 02"
            events.wait(30)
            root.check(view.filteredEntries.length === 1 && view.selectedId === "2", "search, category and all feature filters combine")
            root.find("managementFilter-enabled").selected("false")
            root.check(!view.filteredEntries.length && !view.selectedEntry, "empty results clear selection and details")
            root.find("managementFilter-enabled").selected("true")
            view.category = "personal"
            const filterWidth = root.find("managementFilter-enabled").width
            view.showCategory = false
            events.wait(20)
            root.check(!root.find("managementCategory") && view.filteredEntries.length === 1,
                "disabled work mode removes and ignores the category filter")
            for (const key of ["enabled","browser","type","availability"]) {
                const filter = root.find("managementFilter-" + key) as UI.ComboSelector
                root.check(!!filter && filter.visible && filter.width > filterWidth,"remaining filter expands without Work: " + key)
            }
            const hints = root.find("managementHints")
            root.check(!hints.text.includes("Esc") && !hints.text.includes("Enter"), "Manage omits routine closing and opening hints")
            root.check(hints.verticalAlignment === Text.AlignVCenter && hints.height >= Theme.controlHeight
                && hints.horizontalAlignment === Text.AlignHCenter && Math.abs(hints.mapToItem(view,hints.width / 2,0).x - view.width / 2) < 1
                && Math.abs(hints.mapToItem(view,0,hints.height).y - view.height) < 1
                && Math.abs(hints.mapToItem(view,0,hints.height / 2).y
                    - (view.listView.mapToItem(view,0,view.listView.height).y + view.height) / 2) < 1,
                "Manage hints are centered in their final row across the bottom")
            view.showCategory = true
            view.filterValues = ({}); view.category = ""; view.query = ""
            const selectedId = view.selectedId
            view.searchField.forceActiveFocus()
            events.keyClick(Qt.Key_E,Qt.ControlModifier,0)
            root.check(view.editing,"Ctrl+E edits the selected entry from search")
            webappForm.load(Object.assign(Webapps.empty(Config.defaultBrowserId),{name:"Example webapp",url:"https://example.test",arguments:["--example"]}))
            events.wait(30)
            root.check(!view.searchField.enabled && !view.listView.enabled && !root.find("managementCategory").enabled
                && !root.find("managementAdd").enabled && !root.find("managementFilter-enabled").enabled,"draft locks toolbar, filters and list")
            root.check(view.selectedId === selectedId, "selected list identity stays visible while editing")
            root.check(!root.find("webappAdvanced"),"Advanced toggle is removed")
            const urlField = root.find("webappUrl") as UI.InputField
            const editY = urlField.mapToItem(webappForm,0,0).y
            webappForm.readOnly = true
            root.check(urlField.readOnly && (root.find("webappBrowserSelector") as UI.ComboSelector).readOnly
                && !(root.find("webappEnabled") as UI.CheckBox).enabled,"details prevent field, selector and Enabled edits")
            root.check(urlField.mapToItem(webappForm,0,0).y === editY,"view and edit keep matching field positions")
            root.preview("webapp-details")
            webappForm.readOnly = false
            root.preview("webapp-edit")
            root.formType = 1
            remoteForm.load(Object.assign(Remotes.empty(),{name:"Example remote",endpoint:"fixture.test",hopHost:"jump.test",hopUsername:"user",domain:"Example",password:"synthetic"}))
            events.wait(30); root.preview("remote-edit")
            root.formType = 2
            n8nForm.load(Object.assign(N8n.empty(Config.defaultBrowserId),{name:"Example n8n",url:"https://n8n.example.test",apiKey:"synthetic"}))
            events.wait(30); root.preview("n8n-edit")
            view.editing = false
            root.showList = true
            PickerService.promptMenu("Plain list",[{title:"Example"}],()=>{})
            events.wait(30)
            const originalWidth = plainList.width
            for (const width of [Theme.pickerWidth, Theme.manageWidth]) {
                plainList.width = width
                events.wait(30)
                root.checkPickerAlignment(plainList)
            }
            plainList.width = originalWidth
            PickerService.items = Array.from({length: 60}, (_, i) => ({id: String(i), title: 'Overflow row ' + i}))
            events.wait(30)
            const listScroll = root.find("pickerList", plainList) as UI.PickerList
            const scrollbar = listScroll.children.find(item => item instanceof UI.ScrollBar && item.orientation === Qt.Vertical)
            root.check(scrollbar.needed, "launcher alignment fixture has overflowing results")
            events.mouseMove(scrollbar, scrollbar.width / 2, 10)
            events.wait(Theme.scrollbarGrowDuration + 40)
            root.check(Math.abs(scrollbar.width - Theme.scrollbarHoverWidth) < 0.1, "launcher scrollbar grows on hover")
            root.checkPickerAlignment(plainList)
            root.preview("list-padding")
            events.mouseMove(window.contentItem, 0, 0)
            const plainHints = root.find("pickerFooterHint")
            root.check(!plainHints.visible && plainHints.height === 0
                && Math.abs(plainHints.mapToItem(plainList,0,0).y - (plainList.height - Theme.scrollbarGutter)) < 1,
                "plain lists omit unused footer rows while preserving bottom padding")
            PickerService.begin(PickerService.Mode.Webapps,"Filter geometry")
            filterService.open()
            PickerService.show()
            events.wait(20)
            const filterHeight = plainList.implicitHeight
            root.check(filterPanel.implicitHeight === Theme.pickerHeight,"collection lists use the shared fixed height")
            const openings = root.openingSignals
            root.check(PickerService.items.length === 1,"Work rows start hidden outside work status")
            filterService.toggleShowAll()
            events.wait(20)
            root.check(PickerService.items.length === 20 && plainList.implicitHeight === filterHeight
                && filterPanel.implicitHeight === Theme.pickerHeight && root.openingSignals === openings,
                "Work override reveals rows without reopening or expanding the list")
            filterService.toggleShowAll()
            filterService.activeFilterIds = ["0"]
            filterService.toggleActiveOnly()
            events.wait(20)
            root.check(PickerService.items.length === 1 && plainList.implicitHeight === filterHeight
                && root.openingSignals === openings,"Running-only filtering keeps the same opening geometry")
            filterRepository.entries = []
            events.wait(20)
            root.check(!PickerService.items.length && filterPanel.implicitHeight === Theme.pickerHeight,
                "empty collections reserve the same panel height")
            for (const test of [{service:ProjectService,mode:PickerService.Mode.Projects},
                {service:DirectoryService,mode:PickerService.Mode.Directories}]) {
                PickerService.begin(test.mode,"Filter geometry")
                PickerService.items = [{id:"fixture",title:"Synthetic row",result:"fixture"}]
                PickerService.show()
                const initialOpenings = root.openingSignals
                test.service.toggleShowAll()
                root.check(root.openingSignals === initialOpenings,"Projects/Directories Work filters do not reopen the panel")
            }
            PickerService.close()
            root.showList = false
            root.showWork = true
            work.load()
            events.wait(30)
            const actions = root.find("statusRulesActions") as UI.EditorActions
            const browse = root.find("addStatusWorkFolder") as UI.ActionButton
            root.check(!actions.submitEnabled && !actions.cancelEnabled,"clean rules disable Cancel and Apply")
            root.check(root.find("statusProcessPatterns").mapToItem(work,0,0).y > root.find("statusWorkDirectories").mapToItem(work,0,0).y,
                "Work keeps its original width and stacked text areas")
            root.check(root.find("managementCategory").mapToItem(view,0,0).y > view.searchField.mapToItem(view,0,0).y,
                "category is in the filters row below search")
            root.find("statusProcessPatterns").text = "changed-process"
            events.wait(30)
            root.check(actions.submitEnabled && actions.cancelEnabled,"changes in either rules field enable both actions")
            root.check(actions.mapToItem(work,0,0).x >= browse.mapToItem(work,browse.width,0).x,"rule actions sit right of folder picker")
            actions.submitted()
            root.check(rulesBackend.rules.processes[0] === "changed-process" && !work.dirty,"Apply saves and resets dirty state")
            root.find("statusWorkDirectories").text = "/fixture/unsaved"
            actions.cancelled()
            root.check(root.find("statusWorkDirectories").text === "/fixture/work" && !work.dirty,"Cancel restores saved rules")
            root.preview("work")
            root.settings.animationsEnabled = true
            root.expanded = true
            events.wait(20)
            root.check(motion.transitioning,"expansion uses shared resize animation")
            events.wait(Theme.panelResizeDuration + 40)
            root.check(motion.displayedWidth === Theme.manageWidth,"expanded geometry settles")
            root.audio.screencastActive = true
            root.expanded = false
            events.wait(30)
            root.check(!motion.transitioning && motion.displayedWidth === Theme.pickerWidth,"sharing snaps geometry without decorative motion")
            root.audio.screencastActive = false
            root.settings.animationsEnabled = false
            root.expanded = true
            events.wait(30)
            root.check(!motion.transitioning && motion.displayedWidth === Theme.manageWidth,"disabled motion snaps geometry")
            console.log(root.failed ? "MANAGE FAIL: layout" : "PASS: shared Manage selection, uniform rows, filters, edit context, forms, dirty Work actions and motion policy")
            Qt.quit()
        }
    }
}
