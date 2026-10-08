pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/modules/launcher"
import "../../src/theme/ui" as UI
import "../../src/theme"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    property int moves: 0
    property real originalCardWidth: 0
    function check(ok, message) { if (!ok) { failed = true; console.error("EXPOSE FAIL:", message) } }
    Test.TestCase { id: events; when: false }
    QtObject {
        id: picker
        property bool visible: true
        property string query: ""
        property int currentIndex: 0
        property int exposeWorkspace: 0
        property bool exposeDragging: false
        property int accepted: 0
        property string movedAddress: ""
        property int movedWorkspace: 0
        property var items: Array.from({length: 8}, (_, index) => ({id: "0x" + (index + 1), result: "0x" + (index + 1),
            title: index === 0 ? "Browser" : "Editor " + index, search: index === 0 ? "browser" : "editor", workspaceId: index % 2 + 1,
            client: {address: "0x" + (index + 1), class: "", at: [index % 2 * 400, 0], size: index === 0 ? [800, 600] : index === 1 ? [400, 600] : index === 2 ? [1200, 400] : [400, 300]}}))
        readonly property var filteredItems: items.filter(item => (!exposeWorkspace || item.workspaceId === exposeWorkspace)
            && item.search.includes(query.toLowerCase()))
        readonly property var exposeWorkspaces: Array.from({length: Number(Quickshell.env("EXPOSE_TEST_WORKSPACES") || 3)},
            (_, index) => index + 1).map(id => ({id, name: ["Code", "Browser", "Empty"][id - 1] || "Workspace " + id,
            windows: items.filter(item => item.workspaceId === id).map(item => item.client)}))
        function move(delta) { currentIndex = Math.max(0, Math.min(filteredItems.length - 1, currentIndex + delta)) }
        function select(index, _toggle) { currentIndex = index }
        function selectExposeWorkspace(id) { exposeWorkspace = id; currentIndex = 0 }
        function moveExposeWindow(address, workspace) { movedAddress = address; movedWorkspace = workspace; root.moves++; return true }
        function accept(_custom, _copy) { accepted++; visible = false }
        function close() { visible = false }
        onQueryChanged: currentIndex = 0
    }
    FloatingWindow {
        visible: true
        implicitWidth: Number(Quickshell.env("EXPOSE_TEST_WIDTH") || 1000)
        implicitHeight: Number(Quickshell.env("EXPOSE_TEST_HEIGHT") || 800)
        color: Theme.background
        ExposePanel { id: panel; anchors.fill: parent; anchors.margins: 24; picker: picker }
    }
    Timer {
        interval: 220; running: true; repeat: true
        onTriggered: {
            const search = events.findChild(panel, "exposeSearch") as UI.SearchField
            const grid = events.findChild(panel, "exposeWindows") as ExposeWindowGrid
            const strip = events.findChild(panel, "exposeWorkspaces") as ListView
            if (root.step === 0) {
                root.check(grid.count === 8 && strip.count === picker.exposeWorkspaces.length && search.activeFocus, "overview displays all windows and focuses search")
                const row = strip.parent
                const all = events.findChild(panel, "exposeAllWorkspaces") as UI.ActionButton
                root.check(Math.abs(row.x + row.width / 2 - panel.width / 2) < 1, "workspace strip is centered")
                const controls = search.parent
                root.check(Math.abs(controls.x + controls.width / 2 - panel.width / 2) < 1,
                    "search and Show all are centered together")
                root.check(search.x + search.width <= all.x && controls.y + controls.height <= row.y,
                    "search is left of Show all above the workspace strip")
                root.check(controls.x >= 0 && controls.x + controls.width <= panel.width + 1,
                    "header controls stay within the screen")
                for (let index = 0; index < grid.count; index++) {
                    const card = grid.itemAtIndex(index) as ExposeWindowCard
                    const preview = events.findChild(card, "exposeWindowPreview") as WindowPreview
                    const original = card.entry.client.size
                    root.check(Math.abs(preview.width / preview.height - original[0] / original[1]) < 0.001,
                        "preview follows original window aspect ratio")
                    root.check(card.x >= 0 && card.x + card.width <= grid.width + 1,
                        "proportional cards stay inside the viewport width")
                    const caption = events.findChild(card, "exposeWindowCaption") as Rectangle
                    root.check(Math.abs(preview.y - caption.y - caption.height) < 0.001,
                        "window content meets the bottom of its title bar without a gap")
                }
                const wide = grid.itemAtIndex(0) as ExposeWindowCard
                const narrow = grid.itemAtIndex(1) as ExposeWindowCard
                root.check(Math.abs((wide.width - Theme.controlSpacing * 2)
                    / (narrow.width - Theme.controlSpacing * 2) - 2) < 0.001,
                    "narrow windows occupy proportionally less width")
                root.originalCardWidth = (grid.itemAtIndex(0) as ExposeWindowCard).width
                const label = events.findChild(strip.itemAtIndex(0), "exposeWorkspaceName") as UI.ColumnText
                root.check(label.text === "Code", "workspace names are shown below icons")
                const icon = events.findChild(strip.itemAtIndex(0), "exposeWorkspaceIcon") as UI.IconText
                root.check(icon.font.pixelSize === Math.round(Theme.exposeWorkspaceIconSize * panel.workspaceScale),
                    "workspace icon scales with available screen space")
                root.check(icon.y === Math.round(Theme.exposeWorkspaceTopPadding * panel.workspaceScale),
                    "workspace icon has responsive top padding")
                const preview = events.findChild(strip.itemAtIndex(0), "exposeWorkspaceLayout") as Item
                root.check(label.y >= icon.y + icon.height && preview.y >= label.y + label.height,
                    "icon, name and miniature layout do not overlap")
                const hovered = grid.itemAtIndex(1) as ExposeWindowCard
                events.mouseMove(hovered, hovered.width / 2, hovered.height / 2)
                root.check(picker.currentIndex === 1 && picker.accepted === 0 && picker.visible && search.activeFocus,
                    "hover selects a card without activating it or taking search focus")
                events.mouseMove(search, search.width / 2, search.height / 2)
                picker.currentIndex = 0
                events.keyClick(Qt.Key_Down)
                root.check(picker.currentIndex === grid.columns, "Down navigates one grid row")
                events.keyClick(Qt.Key_Right)
                root.check(picker.currentIndex === grid.columns + 1, "Right navigates a grid column")
                search.text = "browser"
            } else if (root.step === 1) {
                root.check(grid.count === 1 && search.activeFocus, "filtering retains search focus")
                const single = grid.itemAtIndex(0) as ExposeWindowCard
                root.check(single.width > root.originalCardWidth && (Math.abs(single.height - grid.height) < 1 || Math.abs(single.width - grid.width) < 1),
                    "a single window uses the maximum space that fits its geometry")
                const caption = events.findChild(single, "exposeWindowCaption") as Rectangle
                root.check(caption.radius === 0 && caption.color === Theme.background, "window caption is rectangular and opaque")
                search.text = ""
                const workspace = strip.itemAtIndex(1) as WorkspacePreview
                events.mouseClick(workspace, workspace.width / 2, workspace.height - 10)
            } else if (root.step === 2) {
                root.check(picker.exposeWorkspace === 2 && grid.count === 4, "workspace click filters windows")
                const empty = strip.itemAtIndex(2) as WorkspacePreview
                events.mouseClick(empty, empty.width / 2, empty.height - 10)
            } else if (root.step === 3) {
                root.check(grid.count === 0, "empty workspace remains selectable and a drop target")
                const all = events.findChild(panel, "exposeAllWorkspaces") as UI.ActionButton
                events.mouseClick(all, all.width / 2, all.height / 2)
            } else if (root.step === 4) {
                root.check(grid.count === 8 && picker.exposeWorkspace === 0 && search.activeFocus, "All restores the window grid")
                const card = grid.itemAtIndex(0) as ExposeWindowCard
                events.mousePress(card, card.width / 2, card.height / 2)
                events.mouseMove(card, card.width / 2 + 30, card.height / 2 - 20)
            } else if (root.step === 5) {
                root.check(picker.exposeDragging, "dragging freezes window refresh")
                const other = grid.itemAtIndex(1) as ExposeWindowCard
                events.mouseMove(other, other.width / 2, other.height / 2)
                root.check(picker.currentIndex === 0, "dragging across another card keeps the dragged window selected")
                const workspace = strip.itemAtIndex(1) as WorkspacePreview
                const point = workspace.mapToItem(panel, workspace.width / 2, workspace.height / 2)
                events.mouseMove(panel, point.x, point.y)
            } else if (root.step === 6) {
                const card = grid.itemAtIndex(0) as ExposeWindowCard
                const body = card.dragLayer.children.find(child => child.objectName === "exposeDragCard" && child.parent === card.dragLayer && child !== card) as Rectangle
                const left = body.mapToItem(panel, 0, 0)
                const right = body.mapToItem(panel, body.width, 0)
                root.check(card.dragging && Math.abs(right.x - left.x - Math.min(card.width, Theme.exposeDragWidth)) < 1,
                    "dragged card shrinks without changing its grid slot")
                const workspace = strip.itemAtIndex(1) as WorkspacePreview
                root.check(workspace.dropHovered && workspace.color === Theme.accent && picker.exposeWorkspace === 0,
                    "hovering a drop target highlights it without replacing the dragged grid")
                const point = workspace.mapToItem(panel, workspace.width / 2, workspace.height / 2)
                events.mouseRelease(panel, point.x, point.y)
            } else if (root.step === 7) {
                root.check(root.moves === 1 && picker.movedAddress === "0x1" && picker.movedWorkspace === 2
                    && !picker.exposeDragging && picker.accepted === 0 && picker.visible, "drop moves exactly the dragged window without activating it")
                events.keyClick(Qt.Key_Escape)
                root.check(!picker.visible, "Escape dismisses the overview")
                picker.visible = true
                const card = grid.itemAtIndex(0) as ExposeWindowCard
                events.mouseClick(card, card.width / 2, card.height / 2)
                root.check(picker.accepted === 1 && !picker.visible, "click activates the selected window")
                console.log(root.failed ? "EXPOSE FAIL: overview" : "PASS: Exposé centered header, proportional window geometry, single-window sizing, top captions, names, hover selection, grid navigation, filtering, empty workspaces, drag/drop, activation and Escape")
                stop()
                if (Quickshell.env("EXPOSE_TEST_SCREENSHOT")) {
                    panel.grabToImage(result => {
                        result.saveToFile(Quickshell.env("EXPOSE_TEST_SCREENSHOT"))
                        Qt.quit()
                    })
                } else Qt.quit()
                return
            }
            root.step++
        }
    }
}
