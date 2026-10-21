pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/ui" as UI
import "../../src/modules/hyprland" as Modules
import "../../src/services"
import "../../src/config"
import "../../src/theme"
import "../launcher" as Support

WorkerScope {
    id: root
    property var settings: Config
    property bool longTitles: false
    property real titleBudget: 700
    property var compositor: windows.compositor
    readonly property var windows: WindowService
    readonly property UI.TabBar tabs: bar.children.find(item => item instanceof UI.TabBar) ?? null
    function clients(focused, grouped = true, workspace = 4) {
        return [
            {address:"0x1", title:"Alpha", grouped:[]},
            {address:"0x2", title:"Zulu", grouped:grouped ? ["0x2","0x3"] : []},
            {address:"0x3", title:"Beta", grouped:grouped ? ["0x2","0x3"] : []},
            {address:"0x4", title:"Solo", grouped:["0x4"]},
            {address:"0x5", title:"Delta"}
        ].map(client => Object.assign({}, client, {class:"test", floating:false,
            title:root.longTitles ? client.title + " /project/".repeat(100) : client.title,
            workspace:{id:workspace}, focusHistoryID:client.address === focused ? 0 : 1}))
    }
    function update(focused, grouped = true, workspace = 4) {
        compositor.focusedWorkspace = {id:workspace}
        settings.hyprlandGetWindowsCommand = ["printf", "%s", JSON.stringify(clients(focused,grouped,workspace))]
        windows.buildWindows()
    }
    function title() { return driver.find(bar,"activeWindowTitle") as UI.Text }
    function tabLabel(index) {
        const tab = tabs.itemAt(index) as QC.TabButton
        return tab.contentItem.children.find(item => item instanceof UI.Text) as UI.Text
    }
    Test.TestEvent { id: wheelEvents }
    function focusedTabVisible() {
        const tab = tabs.itemAt(tabs.currentIndex)
        if (!tab) return false
        const x = tab.mapToItem(tabs,0,0).x
        return tab.width > tabs.width ? x >= -0.1 && x < tabs.width
            : x >= -0.1 && x + tab.width <= tabs.width + 0.1
    }
    function checkTitleBounds() {
        driver.check(bar.width <= titleBudget + 0.01, "window labels stay before the center modules")
        for (let index = 0; index < tabs.count; index++) {
            const label = tabLabel(index)
            driver.check(tabs.width <= titleBudget / 2 + 0.01, "group occupies at most half the available area")
            driver.check(!label.truncated && label.width >= label.implicitWidth,
                "grouped titles retain their full text for scrolling")
            driver.check(label.color.toString() === (index === tabs.currentIndex ? Theme.accent : Theme.inactive).toString(),
                "full grouped titles keep their text colors")
            const tab = tabs.itemAt(index) as QC.TabButton
            for (const decoration of tab.background.children)
                driver.check(decoration.x >= -0.01 && decoration.x + decoration.width <= tab.width + 0.01,
                    "tab decoration stays within its full-width tab")
        }
        const label = title()
        if (label) {
            driver.check(label.truncated, "long standalone title is elided")
            driver.check(label.color.toString() === Theme.accent.toString(), "standalone ellipsis keeps the accent")
            driver.check(label.mapToItem(bar,0,0).x + label.width <= titleBudget + 0.01,
                "standalone title stays inside the window area")
        }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 900
        implicitHeight: 40
        Modules.Windows { id: bar; maximumWidth: root.titleBudget }
    }
    Support.NativeFocusDriver {
        id: driver
        onFailed: message => {
            console.error("WINDOWS FAIL: " + message + " " + JSON.stringify({budget:root.titleBudget,
                width:bar.width,tabsWidth:root.tabs.width,contentX:(root.tabs.contentItem as ListView).contentX,
                current:root.tabs.currentIndex,positions:Array.from({length:root.tabs.count},(_,i) => ({
                    x:root.tabs.itemAt(i).mapToItem(root.tabs,0,0).x,width:root.tabs.itemAt(i).width}))}))
            Qt.quit()
        }
        onCompleted: {
            console.log("PASS: grouped window tabs, focused standalone title, tab clicks, numbered focus and workspace changes")
            Qt.quit()
        }
    }
    Component.onCompleted: {
        driver.add("mixed workspace", () => root.update("0x1"))
        // Client data can arrive before Qt polishes the Row's geometry.
        driver.waitFor("standalone title after group tabs", () => root.windows.windows.length === 5
            && root.tabs?.count === 2 && root.title()?.text === "alpha" && bar.width > 0, () => {
            driver.check(JSON.stringify(root.tabs.labels) === '["beta","zulu"]', "only actual group members become tabs")
            driver.check(root.tabs.currentIndex === -1, "no group tab selected for a standalone window")
            for (let index = 0; index < root.tabs.count; index++)
                driver.check(!(root.tabs.itemAt(index) as QC.TabButton).checked, "standalone focus clears checked tabs")
            driver.check(root.title().mapToItem(bar,0,0).x >= root.tabs.width,
                "standalone title follows the tab bar: " + JSON.stringify({titleX:root.title().mapToItem(bar,0,0).x,
                    tabsX:root.tabs.x,tabsWidth:root.tabs.width,barWidth:bar.width}))
            driver.click(root.tabs.itemAt(0), root.tabs.itemAt(0).width / 2, 15)
            driver.check(root.compositor.dispatched[root.compositor.dispatched.length - 1].includes('"0x3"'), "tab click targets the filtered member")
            root.windows.focusIndex("1")
            driver.check(root.compositor.dispatched[root.compositor.dispatched.length - 1].includes('"0x3"'), "numbered focus matches visible group order")
        })
        driver.add("focus group member", () => root.update("0x2"))
        driver.waitFor("group focus removes standalone title", () => !root.title() && root.tabs.currentIndex === 1, () => {
            driver.check((root.tabs.itemAt(1) as QC.TabButton).checked, "focused group member is checked")
        })
        driver.add("change focus without changing tab labels", () => root.update("0x3"))
        driver.waitFor("same labels update selection", () => root.tabs.currentIndex === 0)
        driver.add("single member group", () => root.update("0x4"))
        driver.waitFor("single member uses standalone style", () => root.title()?.text === "solo" && root.tabs.currentIndex === -1)
        driver.add("remove group", () => root.update("0x1",false))
        driver.waitFor("no tabs for standalone windows", () => root.tabs.count === 0 && root.title()?.text === "alpha", () => {
            driver.check(!root.tabs.visible && bar.titleWindows.length === 1, "inactive standalone titles are absent")
        })
        driver.add("ordinary workspace", () => root.update("0x2",true,1))
        driver.waitFor("ordinary workspace keeps title style", () => root.tabs.count === 0 && root.title()?.text === "zulu")
        driver.add("long mixed titles", () => {
            root.longTitles = true; root.titleBudget = 300
            root.update("0x1")
        })
        driver.waitFor("long mixed titles fit", () => root.title()?.truncated && root.tabs.count === 2
            && root.tabs.contentWidth > root.tabs.width && bar.width <= root.titleBudget + 0.01, root.checkTitleBounds)
        driver.add("scroll grouped titles", () => {
            const view = root.tabs.contentItem as ListView
            view.positionViewAtBeginning()
            driver.check(wheelEvents.mouseWheel(root.tabs, root.tabs.width / 2, 15, Qt.NoButton, Qt.NoModifier, 0, -120, 0),
                "synthetic wheel reaches the tab bar")
        })
        driver.waitFor("wheel reveals more of the full titles", () => (root.tabs.contentItem as ListView).contentX > 0)
        driver.add("long focused group", () => root.update("0x2"))
        driver.waitFor("long focused group fits", () => !root.title() && root.tabs.currentIndex === 1
            && root.focusedTabVisible() && bar.width <= root.titleBudget + 0.01, root.checkTitleBounds)
        driver.add("focus first long group tab", () => root.update("0x3"))
        driver.waitFor("first grouped title scrolls into view", () => root.tabs.currentIndex === 0
            && root.focusedTabVisible(), root.checkTitleBounds)
        driver.add("shrink available space", () => root.titleBudget = 120)
        driver.waitFor("group follows narrower center boundary", () => root.tabs.width <= 60.01
            && root.focusedTabVisible(), root.checkTitleBounds)
        driver.add("long standalone title", () => root.update("0x1",false))
        driver.waitFor("standalone follows narrow boundary", () => root.tabs.count === 0 && root.title()?.truncated
            && bar.width <= 120.01, root.checkTitleBounds)
        driver.add("no space for titles", () => root.titleBudget = 0)
        driver.waitFor("zero available width", () => bar.width === 0 && root.title()?.width === 0)
        driver.add("restore short titles", () => {
            root.longTitles = false; root.titleBudget = 700
            root.update("0x1",false)
        })
        driver.waitFor("short title returns to natural width", () => root.title()?.text === "alpha"
            && !root.title().truncated && bar.width < root.titleBudget)
        driver.add("empty workspace", () => {
            root.settings.hyprlandGetWindowsCommand = ["printf", "%s", "[]"]
            root.windows.buildWindows()
        })
        driver.waitFor("empty workspace clears titles and tabs", () => !root.title() && root.tabs.count === 0)
        driver.running = true
    }
}
