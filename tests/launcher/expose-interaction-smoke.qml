pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/modules/launcher"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    property var survivor: null
    property var failedCard: null
    property var survivorSlot: null
    property var destinationPreview: null
    property bool previewEntering: false
    function check(ok, message) {
        if (!ok) { failed = true; console.error("EXPOSE FAIL:", message) }
    }
    Test.TestCase { id: events; when: false }
    QtObject {
        id: picker
        property bool visible: true
        property bool exposeDragging: false
        property var exposePendingMoves: ({})
        property int exposeWorkspace: 1
        property int currentIndex: 0
        property int accepted: 0
        property bool failMove: false
        property string query: ""
        property var exposeWorkspaces: [{id: 1, name: "Left"}, {id: 2, name: "Middle"}, {id: 3, name: "Right"}]
        property var items: Array.from({length: 5}, (_, index) => ({
            id: "0x" + (index + 1), title: "Window " + index, workspaceId: index < 3 ? 1 : 2,
            client: {address: "0x" + (index + 1), class: "", at: [index * 400, 0], size: [400, 300]}
        }))
        readonly property var filteredItems: items.filter(item => item.workspaceId === exposeWorkspace)
        function selectExposeWorkspace(workspace) { exposeWorkspace = workspace; currentIndex = 0 }
        function select(index, _toggle) { currentIndex = index }
        function accept(_custom, _copy) { accepted++ }
        function moveExposeWindow(address, workspace) {
            const item = items.find(entry => entry.id === address)
            if (!item || item.workspaceId === workspace) return false
            exposePendingMoves = Object.assign({}, exposePendingMoves, {[address]: workspace})
            if (failMove) rejectMove.restart()
            return true
        }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 800
        ExposePanel { id: panel; anchors.fill: parent; anchors.margins: 24; picker: picker }
    }
    Timer {
        id: rejectMove
        interval: 1000
        onTriggered: {
            picker.exposePendingMoves = ({})
            picker.items = picker.items.map(item => Object.assign({}, item))
        }
    }
    Timer {
        id: checkSlide
        interval: 60
        onTriggered: {
            const grid = events.findChild(panel, "exposeWindows") as ExposeWindowGrid
            const incoming = grid.itemAtIndex(0) as ExposeWindowCard
            const position = incoming.mapToItem(grid, 0, 0)
            const target = grid.arrangement.cards[0]
            root.check(grid.workspaceProgress > 0 && grid.workspaceProgress < 1
                && (position.x - target.x) * grid.workspaceDirection > 1,
                "incoming workspace slides from the selected workspace's direction")
            const snapshot = grid.outgoingCards[0]
            const outgoing = events.findChild(grid, "exposeOutgoing-" + snapshot.entry.id) as ExposeWindowCard
            root.check((outgoing.x - snapshot.x) * grid.workspaceDirection < -1,
                "previous workspace slides out in the opposite direction")
        }
    }
    Timer {
        id: checkWorkspaceFade
        interval: 60
        onTriggered: {
            const strip = events.findChild(panel, "exposeWorkspaces") as ListView
            const tile = strip.itemAtIndex(2) as WorkspacePreview
            const placeholder = events.findChild(tile, "exposeEmptyWorkspaceIcon") as Item
            const previews = events.findChild(tile, "exposeWorkspaceWindows") as Item
            root.check(placeholder.opacity > 0 && placeholder.opacity < 1
                && previews.opacity > 0 && previews.opacity < 1,
                "empty workspace crossfades between its placeholder and the dragged preview")
            if (root.previewEntering) {
                root.check(tile.windows.length === 1 && tile.windows[0].address === "0x1"
                    && !Object.keys(picker.exposePendingMoves).length,
                    "hovering an empty workspace previews the dragged window before dropping")
                root.destinationPreview = events.findChild(tile, "exposeWorkspaceWindow-0x1")
            }
        }
    }
    Timer {
        id: checkDragMotion
        interval: 60
        onTriggered: {
            const grid = events.findChild(panel, "exposeWindows") as ExposeWindowGrid
            const target = grid.arrangement.byId[root.survivor.entry.id]
            root.check(root.survivor === grid.itemAtIndex(1)
                && (Math.abs(root.survivor.x - target.x) > 1
                    || Math.abs(root.survivor.y - target.y) > 1
                    || Math.abs(root.survivor.width - target.width) > 1),
                "dragging away and returning animate surviving cards without recreating them")
        }
    }
    function moveToWorkspace(strip) {
        const tile = strip.itemAtIndex(2) as WorkspacePreview
        const point = tile.mapToItem(panel, tile.width / 2, tile.height / 2)
        events.mouseMove(panel, point.x, point.y)
    }
    Timer {
        interval: 330
        running: true
        repeat: true
        onTriggered: {
            const grid = events.findChild(panel, "exposeWindows") as ExposeWindowGrid
            const strip = events.findChild(panel, "exposeWorkspaces") as ListView
            if (root.step === 0) {
                const empty = strip.itemAtIndex(2) as WorkspacePreview
                const placeholder = events.findChild(empty, "exposeEmptyWorkspaceIcon") as Item
                root.check(!empty.windows.length && placeholder.visible && placeholder.opacity === 1,
                    "empty workspace displays the Exposé placeholder below its name")
                picker.selectExposeWorkspace(2)
                root.check(grid.workspaceDirection === 1 && grid.outgoingCards.length === 3,
                    "selecting a workspace on the right preserves the outgoing grid")
                checkSlide.restart()
            } else if (root.step === 1) {
                root.check(grid.workspaceProgress === 1 && !grid.outgoingCards.length, "workspace transition releases outgoing previews")
                picker.selectExposeWorkspace(1)
                root.check(grid.workspaceDirection === -1 && grid.outgoingCards.length === 2,
                    "selecting a workspace on the left reverses the slide")
                checkSlide.restart()
            } else if (root.step === 2) {
                const card = grid.itemAtIndex(0) as ExposeWindowCard
                root.survivor = grid.itemAtIndex(1)
                events.mousePress(card, card.width / 2, card.height / 2)
                events.mouseMove(card, card.width / 2 + 30, card.height / 2 - 20)
            } else if (root.step === 3 || root.step === 5) {
                root.moveToWorkspace(strip)
                root.check(grid.dragVacated && grid.layoutCount === 2 && !grid.arrangement.byId["0x1"],
                    "moving toward the workspace strip closes the dragged window's gap before dropping")
                checkDragMotion.restart()
                root.previewEntering = true
                checkWorkspaceFade.restart()
            } else if (root.step === 4) {
                const point = grid.mapToItem(panel, grid.width / 2, grid.height - 20)
                events.mouseMove(panel, point.x, point.y)
                root.check(!grid.dragVacated && grid.layoutCount === 3, "returning to the grid makes room for the dragged window")
                checkDragMotion.restart()
                root.previewEntering = false
                checkWorkspaceFade.restart()
            } else if (root.step === 6) {
                root.survivorSlot = grid.arrangement.byId[root.survivor.entry.id]
                const card = grid.itemAtIndex(0) as ExposeWindowCard
                const tile = strip.itemAtIndex(2) as WorkspacePreview
                const point = tile.mapToItem(panel, tile.width / 2, tile.height / 2)
                events.mouseRelease(panel, point.x, point.y)
                root.check(card.dropAccepted && grid.layoutCount === 2, "accepted drop keeps the optimistic layout")
            } else if (root.step === 7) {
                root.check(!picker.exposeDragging && grid.layoutCount === 2 && picker.items[0].workspaceId === 1,
                    "drag cleanup does not reopen the gap while compositor events are pending")
                const destination = strip.itemAtIndex(2) as WorkspacePreview
                root.check(events.findChild(destination, "exposeWorkspaceWindow-0x1") === root.destinationPreview,
                    "accepted drop preserves the destination capture while compositor data is pending")
                picker.items = picker.items.map(item => item.id === "0x1" ? Object.assign({}, item, {workspaceId: 3}) : item)
                picker.exposePendingMoves = ({})
                const previews = events.findChild(destination, "exposeWorkspaceWindows") as Item
                root.check(events.findChild(destination, "exposeWorkspaceWindow-0x1") === root.destinationPreview
                    && previews.opacity === 1, "confirmed move keeps its workspace preview without restarting capture")
                const target = grid.arrangement.byId[root.survivor.entry.id]
                root.check(grid.count === 2 && grid.layoutCount === 2 && target.x === root.survivorSlot.x
                    && target.y === root.survivorSlot.y && target.width === root.survivorSlot.width,
                    "confirmation preserves the already rearranged positions")
            } else if (root.step === 8) {
                picker.items = picker.items.filter(item => item.id !== "0x1")
                picker.failMove = true
                root.failedCard = grid.itemAtIndex(0)
                const card = root.failedCard as ExposeWindowCard
                events.mousePress(card, card.width / 2, card.height / 2)
                events.mouseMove(card, card.width / 2 + 30, card.height / 2 - 20)
            } else if (root.step === 9) {
                root.moveToWorkspace(strip)
                root.check(grid.layoutCount === 1, "second drag closes its source slot")
            } else if (root.step === 10) {
                const tile = strip.itemAtIndex(2) as WorkspacePreview
                const point = tile.mapToItem(panel, tile.width / 2, tile.height / 2)
                events.mouseRelease(panel, point.x, point.y)
                root.check(root.failedCard.dropAccepted && grid.layoutCount === 1, "unconfirmed move stays optimistic")
            } else if (root.step === 11) {
                root.check(grid.layoutCount === 1 && Object.keys(picker.exposePendingMoves).length === 1,
                    "old compositor data cannot undo the pending layout")
            } else if (root.step === 14) {
                const body = events.findChild(root.failedCard, "exposeDragCard") as Rectangle
                root.check(grid.layoutCount === 2 && grid.itemAtIndex(0) === root.failedCard
                    && !root.failedCard.dropAccepted && body.visible,
                    "failed move restores the original card and animates room for it")
                const destination = strip.itemAtIndex(2) as WorkspacePreview
                const placeholder = events.findChild(destination, "exposeEmptyWorkspaceIcon") as Item
                root.check(!destination.windows.length && placeholder.opacity === 1
                    && !events.findChild(destination, "exposeWorkspaceWindow-0x2"),
                    "failed move restores the empty destination placeholder and releases its capture")
                const card = root.failedCard as ExposeWindowCard
                events.mousePress(card, card.width / 2, card.height / 2)
                events.mouseMove(card, card.width / 2 + 30, card.height / 2 - 20)
            } else if (root.step === 15) {
                events.mouseMove(panel, panel.width / 2, 10)
                root.check(grid.layoutCount === 1, "dragging above the grid vacates the slot without a drop target")
            } else if (root.step === 16) {
                events.mouseRelease(panel, panel.width / 2, 10)
                root.check(!root.failedCard.dropAccepted && grid.layoutCount === 2,
                    "rejected drop immediately restores room for the window")
            } else if (root.step === 17) {
                root.check(!picker.exposeDragging && !picker.accepted && grid.layoutCount === 2,
                    "rejected drop finishes without activating a window")
                panel.animationsEnabled = false
                picker.selectExposeWorkspace(2)
                root.check(grid.workspaceProgress === 1 && !grid.outgoingCards.length,
                    "disabled animations switch workspaces immediately")
                console.log(root.failed ? "EXPOSE FAIL: interactions"
                    : "PASS: Exposé directional workspace slides, drag rearrangement, return, optimistic drop, confirmation and rollback")
                stop()
                Qt.quit()
            }
            root.step++
        }
    }
}
