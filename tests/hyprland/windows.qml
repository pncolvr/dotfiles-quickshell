pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../src/ui" as UI
import "../../src/modules/hyprland" as Modules
import "../../src/services"
import "../../src/config"
import "../launcher" as Support

Scope {
    id: root
    property var settings: Config
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
            workspace:{id:workspace}, focusHistoryID:client.address === focused ? 0 : 1}))
    }
    function update(focused, grouped = true, workspace = 4) {
        compositor.focusedWorkspace = {id:workspace}
        settings.hyprlandGetWindowsCommand = ["printf", "%s", JSON.stringify(clients(focused,grouped,workspace))]
        windows.buildWindows()
    }
    function title() { return driver.find(bar,"activeWindowTitle") as UI.Text }
    FloatingWindow {
        visible: true
        implicitWidth: 900
        implicitHeight: 40
        Modules.Windows { id: bar }
    }
    Support.NativeFocusDriver {
        id: driver
        onFailed: message => { console.error("WINDOWS FAIL: " + message); Qt.quit() }
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
        driver.add("empty workspace", () => {
            root.settings.hyprlandGetWindowsCommand = ["printf", "%s", "[]"]
            root.windows.buildWindows()
        })
        driver.waitFor("empty workspace clears titles and tabs", () => !root.title() && root.tabs.count === 0)
        driver.running = true
    }
}
