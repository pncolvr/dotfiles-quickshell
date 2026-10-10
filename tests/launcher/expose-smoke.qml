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
    property var retainedCard: null
    function check(ok, message) { if (!ok) { failed = true; console.error("EXPOSE FAIL:", message) } }
    Test.TestCase { id: events; when: false }
    QtObject {
        id: picker
        property bool visible: true
        property string query: ""
        property int currentIndex: 0
        property int exposeWorkspace: 0
        property int exposeReturnWorkspace: 1
        property bool exposeDragging: false
        property var exposePendingMoves: ({})
        property int accepted: 0
        readonly property var currentItem: filteredItems[currentIndex] ?? null
        property string movedAddress: ""
        property int movedWorkspace: 0
        property bool simulateDropUpdate: false
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
        function toggleExposeAll() { selectExposeWorkspace(exposeWorkspace === 0 ? exposeReturnWorkspace : 0) }
        function selectExposeWorkspace(id) {
            if (!id && exposeWorkspace) exposeReturnWorkspace = exposeWorkspace
            exposeWorkspace = id; currentIndex = 0
        }
        function moveExposeWindow(address, workspace) {
            movedAddress = address; movedWorkspace = workspace; root.moves++
            if (simulateDropUpdate) {
                exposePendingMoves = Object.assign({}, exposePendingMoves, {[address]: workspace})
                delayedMove.restart()
            }
            return true
        }
        function accept(_custom, _copy) { accepted++; visible = false }
        function close() { visible = false }
        onQueryChanged: currentIndex = 0
    }
    Timer {
        id: delayedMove
        interval: 350
        onTriggered: {
            picker.items = picker.items.map(item => item.id === picker.movedAddress
                ? Object.assign({}, item, {workspaceId: picker.movedWorkspace}) : item)
                .sort((a, b) => a.workspaceId - b.workspaceId || a.id.localeCompare(b.id))
            picker.exposePendingMoves = ({})
            checkRearrangement.restart()
        }
    }
    Timer {
        id: checkRearrangement
        interval: 60
        onTriggered: {
            const grid = events.findChild(panel, "exposeWindows") as ExposeWindowGrid
            const index = picker.filteredItems.findIndex(item => item.id === "0x2")
            const card = grid.itemAtIndex(index) as ExposeWindowCard
            root.check(card === root.retainedCard, "workspace updates preserve surviving window cards")
            const target = grid.arrangement.cards[index]
            root.check(Math.abs(card.x - target.x) > 1 || Math.abs(card.y - target.y) > 1,
                "surviving windows animate towards their rearranged positions instead of jumping")
        }
    }
    function testWorkspaceShortcuts(search) {
        search.select(0, 3)
        for (let workspace = 1; workspace <= 10; workspace++) {
            const before = picker.exposeWorkspace
            const available = picker.exposeWorkspaces.some(entry => entry.id === workspace)
            events.keyClick(workspace === 10 ? Qt.Key_0 : Qt.Key_0 + workspace, Qt.ControlModifier)
            check(picker.exposeWorkspace === (available ? workspace : before), "Ctrl+digit selects its numbered workspace")
        }
        events.keyClick(Qt.Key_2, Qt.ControlModifier)
        events.keyClick(Qt.Key_A, Qt.ControlModifier)
        check(picker.exposeWorkspace === 0, "Ctrl+A shows all from a workspace")
        events.keyClick(Qt.Key_A, Qt.ControlModifier)
        check(picker.exposeWorkspace === 2, "Ctrl+A returns to the workspace where the toggle started")
        events.keyClick(Qt.Key_1, Qt.ControlModifier)
        events.keyClick(Qt.Key_A, Qt.ControlModifier)
        events.keyClick(Qt.Key_A, Qt.ControlModifier)
        check(picker.exposeWorkspace === 1, "a different workspace becomes the next toggle's return view")
        const selected = picker.currentItem.id
        for (let workspace = 1; workspace <= 10; workspace++) {
            const before = root.moves
            const available = picker.exposeWorkspaces.some(entry => entry.id === workspace)
            events.keyClick(workspace === 10 ? Qt.Key_0 : Qt.Key_0 + workspace, Qt.ControlModifier | Qt.ShiftModifier)
            check(root.moves === before + (available ? 1 : 0)
                && (!available || (picker.movedAddress === selected && picker.movedWorkspace === workspace))
                && picker.exposeWorkspace === 1, "Ctrl+Shift+digit moves the selected window without following it")
        }
        events.keyClick(Qt.Key_2, Qt.ControlModifier)
        const before = root.moves
        events.keyClick(Qt.Key_1, Qt.ControlModifier | Qt.ShiftModifier)
        check(root.moves === before, "moving from an empty filtered view is harmless")
        check(search.activeFocus && search.text === "browser" && search.selectedText === "bro"
            && picker.visible && !picker.accepted, "shortcuts preserve search text, selection, focus and the open overview")
        check(panel.workspaceForKey({key: Qt.Key_Exclam, nativeScanCode: 10}) === 1
            && panel.workspaceForKey({key: Qt.Key_Equal, nativeScanCode: 19}) === 10,
            "shifted number-row punctuation maps to the original workspace digits")
        picker.selectExposeWorkspace(0)
        root.moves = 0
    }
    FloatingWindow {
        visible: true
        implicitWidth: Number(Quickshell.env("EXPOSE_TEST_WIDTH") || 1000)
        implicitHeight: Number(Quickshell.env("EXPOSE_TEST_HEIGHT") || 800)
        color: Theme.background
        ExposePanel { id: panel; anchors.fill: parent; anchors.margins: 24; picker: picker }
    }
    Timer {
        interval: 330; running: true; repeat: true
        onTriggered: {
            const search = events.findChild(panel, "exposeSearch") as UI.SearchField
            const grid = events.findChild(panel, "exposeWindows") as ExposeWindowGrid
            const strip = events.findChild(panel, "exposeWorkspaces") as ListView
            if (root.step === 0) {
                root.check(grid.count === 8 && strip.count === picker.exposeWorkspaces.length && search.activeFocus, "overview displays all windows and focuses search")
                const row = strip.parent
                root.check(Math.abs(row.x + row.width / 2 - panel.width / 2) < 1, "workspace strip is centered")
                const controls = search.parent
                root.check(Math.abs(controls.x + controls.width / 2 - panel.width / 2) < 1,
                    "search is centered")
                root.check(controls.y + controls.height <= row.y,
                    "search sits above the workspace strip")
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
                const previewWidth = wide.previewItem.width
                panel.transitionProgress = 0.5
                root.check(wide.previewItem.width === previewWidth && wide.width === root.originalCardWidth,
                    "camera animation keeps thumbnail geometry fixed")
                panel.transitionProgress = 1
                root.check(strip.contentWidth <= strip.width + 1, "all workspace tiles fit without scrolling")
                for (let index = 0; index < strip.count; index++) {
                    const tile = strip.itemAtIndex(index) as WorkspacePreview
                    const position = tile.mapToItem(strip, 0, 0)
                    root.check(position.x >= 0 && position.x + tile.width <= strip.width + 1,
                        "every workspace tile remains on screen")
                }
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
                root.testWorkspaceShortcuts(search)
                search.text = ""
                const workspace = strip.itemAtIndex(1) as WorkspacePreview
                events.mouseClick(workspace, workspace.width / 2, workspace.height - 10)
            } else if (root.step === 2) {
                root.check(picker.exposeWorkspace === 2 && grid.count === 4, "workspace click filters windows")
                const empty = strip.itemAtIndex(2) as WorkspacePreview
                events.mouseClick(empty, empty.width / 2, empty.height - 10)
            } else if (root.step === 3) {
                root.check(grid.count === 0, "empty workspace remains selectable and a drop target")
                events.keyClick(Qt.Key_A, Qt.ControlModifier)
            } else if (root.step === 4) {
                root.check(grid.count === 8 && picker.exposeWorkspace === 0 && search.activeFocus, "Ctrl+A restores the window grid")
                picker.simulateDropUpdate = true
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
                root.retainedCard = grid.itemAtIndex(1)
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
                root.check(card.dropAccepted && !body.visible, "accepted drop never snaps visibly back to its grid slot")
            } else if (root.step === 7) {
                root.check(root.moves === 1 && picker.movedAddress === "0x1" && picker.movedWorkspace === 2
                    && !picker.exposeDragging && picker.accepted === 0 && picker.visible, "drop moves exactly the dragged window without activating it")
                const card = grid.itemAtIndex(0) as ExposeWindowCard
                const body = events.findChild(card, "exposeDragCard") as Rectangle
                root.check(card.dropAccepted && !body.visible && card.entry.workspaceId === 1,
                    "accepted card stays hidden after drag cleanup while the workspace update is delayed")
            } else if (root.step === 8) {
                const updated = grid.itemAtIndex(picker.filteredItems.findIndex(item => item.id === "0x1")) as ExposeWindowCard
                const body = events.findChild(updated, "exposeDragCard") as Rectangle
                root.check(!updated.dropAccepted && body.visible && updated.entry.workspaceId === 2,
                    "confirmed workspace update restores the card in the updated grid")
                const index = picker.filteredItems.findIndex(item => item.id === "0x2")
                const target = grid.arrangement.cards[index]
                root.check(Math.abs(root.retainedCard.x - target.x) < 1 && Math.abs(root.retainedCard.y - target.y) < 1,
                    "rearranged windows settle at their final grid positions")
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
