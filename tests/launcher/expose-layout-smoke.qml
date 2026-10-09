pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/modules/launcher"
import "../../src/theme"

Scope {
    id: root
    property bool failed: false
    property int step: 0
    property var original: []
    property var retainedCard: null
    property real desktopScale: 0
    function check(ok, message) {
        if (!ok) { failed = true; console.error("EXPOSE FAIL:", message) }
    }
    function checkLayout(grid) {
        const geometry = grid.arrangement
        root.check(geometry.spatial, "ordinary workspace uses its desktop layout")
        const code = geometry.byId["0x1"]
        const files = geometry.byId["0x2"]
        const terminal = geometry.byId["0x3"]
        root.check(code.x + code.width + Theme.exposeSpacing <= files.x + 0.001
            && Math.abs(files.x - terminal.x) < 0.001 && code.y === files.y
            && files.y + files.height + Theme.exposeSpacing <= terminal.y + 0.001,
            "Code stays left, with the file manager above the terminal on the right")
        const scale = (code.width - Theme.controlSpacing * 2) / 1275
        root.check(Math.abs((files.width - Theme.controlSpacing * 2) / 1275 - scale) < 0.001
            && Math.abs((terminal.height - Theme.controlHeight - Theme.controlSpacing - 1) / 700 - scale) < 0.001,
            "desktop layout preserves window proportions and a common scale")
        const right = Math.max(...geometry.cards.map(card => card.x + card.width))
        const left = Math.min(...geometry.cards.map(card => card.x))
        root.check(right <= grid.width + 0.001 && left >= 0
            && (Math.abs(right - left - grid.width) < 1 || Math.abs(geometry.height - grid.height) < 1),
            "desktop layout uses the available width or height without clipping captions")
        return scale
    }
    Test.TestCase { id: events; when: false }
    QtObject {
        id: picker
        property int exposeWorkspace: 4
        property bool exposeDragging: false
        property var exposePendingMoves: ({})
        property int currentIndex: 0
        property string query: ""
        property var exposeWorkspaces: [{id: 4, name: "Code"}]
        // Scrambled input ensures desktop geometry, rather than model order, controls placement.
        property var items: [
            {id: "0x3", title: "Ghostty", workspaceId: 4,
                client: {address: "0x3", class: "", at: [1283, 738], size: [1275, 700], floating: false, grouped: []}},
            {id: "0x1", title: "Code", workspaceId: 4,
                client: {address: "0x1", class: "", at: [2, 32], size: [1275, 1406], floating: false, grouped: ["0x1"]}},
            {id: "0x2", title: "PCManFM", workspaceId: 4,
                client: {address: "0x2", class: "", at: [1283, 32], size: [1275, 700], floating: false, grouped: []}}
        ]
        readonly property var filteredItems: items.filter(entry => entry.title.includes(query))
        function select(index, _toggle) { currentIndex = index }
        function move(delta) { currentIndex = Math.max(0, Math.min(filteredItems.length - 1, currentIndex + delta)) }
        function close() {}
        function moveExposeWindow(_address, _workspace) { return false }
        function accept(_custom, _copy) {}
    }
    FloatingWindow {
        id: surface
        visible: true
        implicitWidth: 1400
        implicitHeight: 900
        ExposePanel { id: panel; anchors.fill: parent; anchors.margins: 24; picker: picker; animationsEnabled: false }
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            const grid = events.findChild(panel, "exposeWindows") as ExposeWindowGrid
            if (root.step === 0) {
                root.original = picker.items
                root.desktopScale = root.checkLayout(grid)
                root.retainedCard = grid.itemAtIndex(1)
                picker.currentIndex = 2
                grid.moveVertical(1)
                root.check(picker.filteredItems[picker.currentIndex].id === "0x3", "Down from file manager selects terminal")
                grid.moveVertical(-1)
                root.check(picker.filteredItems[picker.currentIndex].id === "0x2", "Up from terminal selects file manager")
                picker.currentIndex = 0
                grid.moveHorizontal(-1)
                root.check(picker.filteredItems[picker.currentIndex].id === "0x1", "Left from terminal selects Code")
                grid.moveHorizontal(1)
                root.check(picker.filteredItems[picker.currentIndex].id === "0x2", "Right from Code selects nearest window in right column")
                const filesX = grid.arrangement.byId["0x2"].x
                grid.dragAddress = "0x1"
                grid.dragVacated = true
                root.check(grid.layoutCount === 2 && !grid.arrangement.byId["0x1"]
                    && grid.arrangement.byId["0x2"].x < filesX, "drag vacancy recenters the surviving desktop column")
                grid.dragVacated = false
                root.check(Math.abs(grid.arrangement.byId["0x2"].x - filesX) < 0.001
                    && grid.itemAtIndex(1) === root.retainedCard, "returning restores room without recreating cards")
                grid.dragAddress = ""
                picker.exposeWorkspace = 0
                const packedScale = (grid.arrangement.byId["0x1"].width - Theme.controlSpacing * 2) / 1275
                root.check(!grid.arrangement.spatial && root.desktopScale > packedScale,
                    "desktop topology allows larger previews than the packed all-workspace layout")
                picker.exposeWorkspace = 4
                picker.items = [...picker.items].reverse()
            } else if (root.step === 1) {
                root.checkLayout(grid)
                root.check(grid.itemAtIndex(1) === root.retainedCard, "input reordering preserves the Code capture")
                surface.implicitWidth = 480
                surface.implicitHeight = 620
            } else if (root.step === 2) {
                root.checkLayout(grid)
                picker.items = root.original.map(entry => Object.assign({}, entry, {
                    client: Object.assign({}, entry.client, {floating: entry.id === "0x3"})
                }))
                root.check(!grid.arrangement.spatial && grid.count === 3, "floating windows retain accessible packed cards")
                picker.items = root.original.map(entry => Object.assign({}, entry, {
                    client: Object.assign({}, entry.client, {grouped: entry.id === "0x1" ? ["0x1", "0x4"] : []})
                }))
                root.check(!grid.arrangement.spatial && grid.count === 3, "grouped application tabs retain packed cards")
                picker.items = root.original
                picker.query = "Code"
            } else if (root.step === 3) {
                const card = grid.itemAtIndex(0) as ExposeWindowCard
                root.check(grid.count === 1 && card === root.retainedCard
                    && (Math.abs(card.height - grid.height) < 1 || Math.abs(card.width - grid.width) < 1),
                    "filtering preserves the capture and maximizes the remaining window")
                console.log(root.failed ? "EXPOSE FAIL: desktop layout"
                    : "PASS: Exposé desktop geometry, larger previews, directional navigation, drag vacancy, resizing and grouped/floating fallback")
                stop()
                Qt.quit()
            }
            root.step++
        }
    }
}
