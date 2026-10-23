pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/ui" as UI
import "../../src/theme"

// Real native menu/service, isolated storage and mock power/session executables.
WorkerScope {
    id: root
    property bool failed: false
    property var status: StatusService
    property int replacementCalls: 0
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        visible: true
        implicitWidth: 640
        implicitHeight: panel.implicitHeight
        PickerPanel { id: panel; width: parent.width; height: implicitHeight }
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function checkMenu() {
        check(PickerService.visible && PickerService.mode === PickerService.Mode.Menu && PickerService.layout === "grid",
            "Power reuses the native menu and existing grid")
        check(PickerService.requestDirectory === "" && !!PickerService.menuCallback, "native menu has no shell request/reply")
        check(JSON.stringify(PickerService.items.map(item => item.title)) === JSON.stringify(["Reboot","Lock","Logout","Shutdown","Bios"]),
            "original action order is preserved")
        check(PickerService.items.every(item => item.glyph.length === 1) && !PickerService.allowTyped,
            "original icon glyphs and selection-only behavior are preserved")
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            try {
                PowerService.open()
                root.checkMenu()
                events.wait(30)
                const field = events.findChild(panel, "pickerSearch")
                root.check(!!field && field.activeFocus, "existing search receives focus")
                const grid = events.findChild(panel, "pickerList") as UI.PickerList
                const footer = events.findChild(panel, "pickerFooter") as Item
                root.check(panel.height - footer.mapToItem(panel, 0, footer.height).y === 0,
                    "power launcher bottom padding matches its side padding")
                grid.forceLayout()
                for (let index = 0; index < 5; index++) {
                    const tile = grid.itemAtIndex(index)
                    root.check(!!tile && tile.height === Theme.pickerGridHeight,
                        "naturally sized power grid preserves full-height action tiles: "
                        + JSON.stringify({tileHeight:tile?.height, gridHeight:grid.height,
                            contentWidth:grid.contentWidth, width:grid.width, gutter:grid.horizontalGutter,
                            panelHeight:panel.height, naturalHeight:panel.implicitHeight}))
                    root.check(tile.mapToItem(grid, 0, 0).y === 0,
                        "fitting power grid has no unused horizontal scrollbar gutter")
                }
                panel.width = 360
                events.wait(20)
                grid.forceLayout()
                root.check(grid.contentWidth > grid.width
                    && grid.height === Theme.pickerGridHeight + Theme.scrollbarGutter * 2,
                    "narrow power launcher grows to reserve its horizontal scrollbar")
                root.check(grid.currentItem.height === Theme.pickerGridHeight
                    && grid.currentItem.mapToItem(grid, 0, 0).y === Theme.scrollbarGutter,
                    "overflowing power tiles keep their full height above the scrollbar")
                panel.width = 640
                events.wait(20)
                field.text = "Lock"
                root.check(PickerService.filteredItems.length === 1 && PickerService.currentItem.result === "Lock", "native search filters actions")
                events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                root.check(!PickerService.visible && !PickerService.menuCallback && root.status.pauseCalls === 0,
                    "Escape cancels without a command or stale callback")
                root.check(!PowerService.execute("Lock; shutdown") && root.status.pauseCalls === 0, "unknown actions never pause or execute")
                for (let index = 0; index < 5; index++) {
                    PowerService.open()
                    root.checkMenu()
                    events.wait(15)
                    PickerService.select(index, false)
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
                    root.check(!PickerService.visible && !PickerService.menuCallback && root.status.pauseCalls === index + 1,
                        "acceptance closes and dispatches exactly one action")
                    root.check(root.status.pausedWithMenuClosed, "tracking pauses after picker closure and before execution")
                    events.wait(30)
                }
                PowerService.open()
                PickerService.promptMenu("Replacement", [{title: "Keep working"}], () => root.replacementCalls++)
                PickerService.accept(false, false)
                root.check(root.replacementCalls === 1 && root.status.pauseCalls === 5,
                    "replacement discards the previous action and retains its own callback")
                PickerService.promptMenu("First", [{title: "Next"}], () => {
                    root.check(!PickerService.visible, "callback runs after logical close")
                    PickerService.promptMenu("Second", [{title: "Done"}], () => root.replacementCalls++)
                })
                PickerService.accept(false, false)
                root.check(PickerService.visible && PickerService.prompt === "Second" && !!PickerService.menuCallback,
                    "a callback can safely open the next native step")
                PickerService.accept(false, false)
                root.check(root.replacementCalls === 2 && !PickerService.visible && !PickerService.menuCallback,
                    "the second callback runs once and clears")
                events.wait(100)
                console.log("PASS: native Power grid, filtering, Escape, allowlist, all five actions, status pause and reusable callback lifecycle")
            } catch (error) {
                root.failed = true
                console.error("POWER FAIL:", error)
            }
            PickerService.close()
            Qt.quit()
        }
    }
}
