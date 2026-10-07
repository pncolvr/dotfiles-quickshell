pragma ComponentBehavior: Bound

import QtQuick
import QtTest as Test
import Quickshell
import "../../src/modules/system/files"
import "../../src/services"
import "../../src/theme"
import "../../src/theme/ui" as UI

Scope {
    id: root
    readonly property string phase: Quickshell.env("RECENT_PINS_ORDER_TEST_PHASE")
    readonly property string folder: Quickshell.env("RECENT_FILES_TEST_FOLDER")
    readonly property string recentPath: Quickshell.env("RECENT_FILES_TEST_FILE")
    property int step: 0
    property int ticks: 0
    property bool failed: false
    property var originalOrder: []
    property var expectedOrder: []
    property var event: null
    property string payload: ""
    readonly property UI.TabBar tabs: mouse.findChild(panel, "recentFilesTabs") as UI.TabBar
    readonly property ListView list: mouse.findChild(panel, "recentFilesList") as ListView
    function uri(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/") }
    function order() { return RecentFilesService.pinnedFiles.map(file => file.uri) }
    function same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }
    function check(ok, message) {
        if (ok) return
        failed = true
        console.error("RECENT FILES FAIL:", message)
    }
    function finish() {
        console.log(failed ? "RECENT FILES FAIL: pin order " + phase : "PASS: recent-file pin order " + phase)
        Qt.quit()
    }
    function fileEvent(urls) {
        return {hasUrls: true, urls: urls, supportedActions: Qt.CopyAction, accepted: false,
            action: Qt.IgnoreAction, accept: function(action) { this.action = action; this.accepted = true }}
    }
    function controlledDrag(files, originTab) {
        // Internal drags let the offscreen test keep the source active across
        // model replacement. URL delivery uses the native-event adapter.
        panel.dragSource.Drag.dragType = Drag.Internal
        panel.dragSource.prepare(files, originTab)
        panel.dragPanelHeight = panel.height
        RecentFilesService.beginDrag()
        TooltipService.beginDrag()
        panel.dragSource.dragging = true
        payload = panel.dragSource.Drag.mimeData["text/uri-list"]
        event = fileEvent(files.map(file => file.uri))
    }
    Test.TestCase { id: mouse; parent: testWindow.contentItem; when: false }
    FloatingWindow {
        id: testWindow
        visible: true
        implicitWidth: 500; implicitHeight: 650
        color: Theme.background
        RecentFilesTooltip { id: panel; x: 20; y: 20 }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (++root.ticks > 80) { root.check(false, "pin order timeout at step " + root.step); root.finish(); return }
            if (RecentFilesService.loading || PinnedFilesService.checking || PinnedFilesService.importing) return
            if (root.phase === "restart") {
                if (root.step === 0) {
                    const paths = [root.folder + "/item04.txt", root.recentPath, root.folder + "/item01.txt",
                        root.folder + "/item03.txt", root.folder + "/item02.txt", root.folder + "/item05.txt"]
                    root.check(root.same(root.order(), paths.map(root.uri)), "manual pin order survives shell restart")
                    RecentFilesService.selectPinned()
                } else if (root.step === 1) {
                    root.check(root.same(RecentFilesService.files.map(file => file.uri), root.order()),
                        "Pinned renders the persisted manual order")
                    for (const file of RecentFilesService.pinnedFiles.slice()) RecentFilesService.togglePin(file)
                } else {
                    root.check(root.tabs.count === 1 && RecentFilesService.pinnedFiles.length === 0,
                        "fixture unpins cleanly after verifying persistence")
                    root.finish(); return
                }
                root.step++; return
            }
            if (root.step === 0) {
                root.check(root.tabs.count === 1, "reorder fixture starts with no pins")
                RecentFilesService.togglePin(RecentFilesService.files[0])
                RecentFilesService.pinUrls([1, 2, 3, 4].map(i => root.uri(root.folder + "/item0" + i + ".txt")))
            } else if (root.step === 1) {
                root.originalOrder = root.order()
                root.check(root.originalOrder.length === 5, "five independent pins are ready")
                const incoming = {uri: root.uri(root.folder + "/item05.txt"), icon: "text-x-generic"}
                root.controlledDrag([incoming], "recent")
                panel.hoverPinned(root.event)
            } else if (root.step === 2) {
                root.check(!RecentFilesService.showingPinned, "brief drag hover does not immediately switch tabs")
                root.tabs.tabDragExited(1)
            } else if (root.step === 3) {
                panel.hoverPinned(root.fileEvent(["https://example.com/file.txt"]))
            } else if (root.step === 7) {
                root.check(!RecentFilesService.showingPinned, "leaving the header and invalid drags cancel tab activation")
                panel.hoverPinned(root.event)
            } else if (root.step === 11) {
                root.check(RecentFilesService.showingPinned && root.tabs.currentIndex === 1
                    && RecentFilesService.dragging && panel.dragSource.dragging,
                    "holding a file drag over Pinned opens it while the drag stays active")
                root.check(panel.dragSource.Drag.mimeData["text/uri-list"] === root.payload
                    && panel.height === panel.dragPanelHeight, "tab switch preserves the source payload and panel height")
                root.list.forceLayout()
                panel.updatePinDropPosition(1)
                root.check(panel.pinDropIndex === 0 && panel.pinDropBeforeUri === root.originalOrder[0],
                    "top-half drop targets the position before the first pin")
                panel.pinDrop(root.event, panel.pinDropBeforeUri)
                root.check(root.event.accepted && root.event.action === Qt.CopyAction, "cross-tab pin drop is accepted")
            } else if (root.step === 12) {
                root.check(root.same(root.order(), root.originalOrder), "pin import waits for drag completion")
                panel.dragSource.finish()
            } else if (root.step === 13) {
                root.expectedOrder = [root.uri(root.folder + "/item05.txt")].concat(root.originalOrder)
                root.check(root.same(root.order(), root.expectedOrder), "new document is inserted at the drop position")
                panel.selectFile(root.expectedOrder[1], Qt.NoModifier)
                panel.selectFile(root.expectedOrder[5], Qt.ControlModifier)
                root.controlledDrag(panel.selectedFiles, "pinned")
                const row = root.list.itemAtIndex(3)
                panel.updatePinDropPosition(row.y - root.list.contentY + row.height / 4)
                root.check(panel.pinDropIndex === 3, "row midpoint determines the insertion slot")
                const moving = [root.expectedOrder[1], root.expectedOrder[5]]
                const anchor = root.expectedOrder[3]
                root.originalOrder = root.expectedOrder
                root.expectedOrder = root.expectedOrder.filter(value => !moving.includes(value))
                root.expectedOrder.splice(root.expectedOrder.indexOf(anchor), 0, ...moving)
                panel.pinDrop(root.event, panel.pinDropBeforeUri)
            } else if (root.step === 14) {
                root.check(root.same(root.order(), root.originalOrder), "group reordering waits until the source drag ends")
                panel.dragSource.finish()
            } else if (root.step === 15) {
                root.check(root.same(root.order(), root.expectedOrder) && panel.selectedUris.length === 2,
                    "group reorder retains relative order and selected files")
                const sameOrder = root.order()
                RecentFilesService.reorderPins([sameOrder[2], sameOrder[3]], sameOrder[2])
                root.check(root.same(root.order(), sameOrder), "dropping a group onto itself leaves its order intact")
                root.check(!RecentFilesService.reorderPins(["file:///not-a-pin"], ""), "unknown pins cannot be reordered")
                RecentFilesService.reorderPins([sameOrder[0]], "")
                root.expectedOrder = sameOrder.slice(1).concat(sameOrder.slice(0, 1))
            } else if (root.step === 16) {
                root.check(root.same(root.order(), root.expectedOrder), "a single pin can move to the end")
                root.finish(); return
            }
            root.step++
        }
    }
}
