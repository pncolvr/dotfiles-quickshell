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
    property int step: 0
    property int waitTicks: 0
    property bool failed: false
    property var firstSnapshot: null
    function check(ok, message) {
        if (ok) return
        failed = true
        console.error("RECENT FILES FAIL:", message)
    }
    QtObject {
        id: backend
        property var files: Array.from({length: 20}, (_, index) => ({
            name: "Recent document " + index + ".txt", path: "/tmp/recent file #" + index + ".txt",
            directory: "/tmp", uri: "file:///tmp/recent%20file%20%23" + index + ".txt",
            usedAt: Date.now(), icon: "text-x-generic"
        }))
        property bool loading: false
        property bool dragging: false
        property string error: ""
        property string opened: ""
        property var folders: []
        property var pinnedFiles: []
        property bool showingPinned: false
        readonly property string activeTab: showingPinned ? "pinned" : activeFolder ? "folder" : "recent"
        property string defaultTab: "recent"
        property string activeFolder: ""
        readonly property string currentFolder: activeFolder
        property bool canNavigateUp: false
        property string defaultFolder: ""
        property var folderAliases: ({})
        property int panels: 0
        property int refreshes: 0
        function beginPanel() { panels++ }
        function endPanel() { panels-- }
        function beginDrag() { dragging = true }
        function endDrag() { dragging = false }
        function refresh() { refreshes++ }
        function openFile(file) { opened = file.uri }
        function isPinned(uri) { return pinnedFiles.some(file => file.uri === uri) }
        function togglePin(file) { pinnedFiles = isPinned(file.uri)
            ? pinnedFiles.filter(entry => entry.uri !== file.uri) : pinnedFiles.concat([file]) }
        function selectPinned() { activeFolder = ""; showingPinned = true; files = pinnedFiles }
        function selectFolder(path) { activeFolder = path }
        function setDefaultTab(tab, path = "") { defaultTab = tab; defaultFolder = tab === "folder" ? path : "" }
        function folderLabel(path) { return folderAliases[path] || path.split("/").pop() }
        function setFolderAlias(path, name) { folderAliases = Object.assign({}, folderAliases, {[path]: name}); return true }
        function addFolder(path) { folders = folders.concat([path]); activeFolder = path }
        function removeFolder(path) { folders = folders.filter(folder => folder !== path); activeFolder = "" }
    }
    Test.TestCase { id: mouse; when: false }
    Component.onCompleted: RecentFilesService.beginPanel()
    Component.onDestruction: RecentFilesService.endPanel()
    FloatingWindow {
        visible: true
        implicitWidth: 500
        implicitHeight: 650
        color: Theme.background
        RecentFilesTooltip { id: panel; fileService: backend; x: 20; y: 20 }
    }
    Timer {
        interval: 150; repeat: true; running: true
        onTriggered: {
            if (root.step === 0 && RecentFilesService.loading && root.waitTicks++ < 30) return
            const list = panel.children.find(child => child.objectName === "recentFilesList") as ListView
            if (root.step === 0) {
                root.check(RecentFilesService.error === "" && RecentFilesService.files.length === 1,
                    "recent-file service reads desktop XBEL records")
                root.firstSnapshot = RecentFilesService.files
                root.check(RecentFilesService.files[0]?.path === Quickshell.env("RECENT_FILES_TEST_FILE"),
                    "service preserves the real file path")
                root.check(backend.panels === 1 && list.count === 20, "panel subscribes and exposes files")
                root.check(panel.height <= panel.maxPanelHeight, "list stays within screen height")
                root.check(list.contentHeight > list.height, "long list scrolls")
                const row = list.itemAtIndex(0) as RecentFileRow
                root.check(row.Drag.dragType === Drag.Automatic && row.Drag.supportedActions === Qt.CopyAction,
                    "file drag uses the native copy action")
                root.check(row.Drag.mimeData["text/uri-list"] === backend.files[0].uri + "\r\n", "drag payload is a file URI")
                mouse.mouseDoubleClickSequence(row, row.width / 2, row.height / 2)
                root.check(backend.opened === backend.files[0].uri, "double-click opens the file")
                const screenshot = Quickshell.env("RECENT_FILES_TEST_SCREENSHOT")
                if (screenshot) panel.grabToImage(result => result.saveToFile(screenshot))
                TooltipService.show(0, null, null, false, null)
                TooltipService.setPanelHovered(false)
                TooltipService.beginDrag()
                TooltipService.hide()
                RecentFilesService.beginDrag()
                RecentFilesService.refresh()
                root.check(!RecentFilesService.loading, "refresh is deferred during a drag")
            } else if (root.step < 4) {
                root.check(TooltipService.visible && TooltipService.dragging, "panel survives leaving it during a drag")
            } else if (root.step === 4) {
                TooltipService.endDrag()
                RecentFilesService.endDrag()
                backend.files = []
            } else if (root.step === 7) {
                if (RecentFilesService.loading && root.waitTicks++ < 30) return
                root.check(RecentFilesService.files !== root.firstSnapshot && RecentFilesService.error === "",
                    "queued refresh resumes after the drop")
                root.check(!TooltipService.visible && !TooltipService.dragging, "normal dismissal resumes after the drag")
                root.check(list.count === 0 && panel.height > 0, "empty state has a bounded panel")
                backend.folders = Array.from({length: 20}, (_, index) => "/tmp/folder " + index)
            } else if (root.step === 8) {
                const tabs = mouse.findChild(panel, "recentFilesTabs") as UI.TabBar
                const view = tabs.contentItem as ListView
                root.check(tabs.count === 21 && view.contentWidth > view.width && view.interactive,
                    "many folder tabs use a horizontal scrolling view")
                root.check(tabs.clip, "overflow tabs cannot cover the plus button")
                const plus = mouse.findChild(panel, "addFolderTab") as Item
                const pos = plus.mapToItem(panel, plus.width, 0)
                root.check(plus.visible && Math.abs(pos.x - panel.width) < 1, "plus stays at the far right during overflow")
                mouse.mouseWheel(view, view.width / 2, view.height / 2, -120, 0)
            } else if (root.step === 10) {
                const tabs = mouse.findChild(panel, "recentFilesTabs") as UI.TabBar
                const view = tabs.contentItem as ListView
                root.check(view.contentX > 0, "horizontal wheel scrolls the overflow tabs")
                view.cancelFlick()
                view.contentX = 0
                mouse.mouseWheel(view, view.width / 2, view.height / 2, 0, -120)
            } else if (root.step === 12) {
                const tabs = mouse.findChild(panel, "recentFilesTabs") as UI.TabBar
                const view = tabs.contentItem as ListView
                root.check(view.contentX > 0, "vertical mouse wheel also scrolls horizontal tabs")
                console.log(root.failed ? "FAIL: recent-file panel" : "PASS: recent-file panel, limits, tab overflow, scrolling, URI drag payload, double-click and drag dismissal")
                Qt.quit()
            }
            root.step++
        }
    }
}
