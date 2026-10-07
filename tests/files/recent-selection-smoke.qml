pragma ComponentBehavior: Bound

import QtQuick
import QtTest as Test
import Quickshell
import "../../src/modules/system/files"
import "../../src/theme"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    property string nativePayload: ""
    property string expectedPayload: ""
    function check(ok, message) {
        if (ok) return
        failed = true
        console.error("RECENT FILES FAIL:", message)
    }
    function row(index) { return list.itemAtIndex(index) as RecentFileRow }
    function click(index, modifiers = Qt.NoModifier) {
        const item = row(index)
        mouse.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, modifiers)
    }
    readonly property ListView list: mouse.findChild(panel, "recentFilesList") as ListView
    QtObject {
        id: backend
        property var files: Array.from({length: 6}, (_, index) => ({
            name: "File " + index + ".txt", directory: "/tmp", usedAt: Date.now(),
            uri: "file:///tmp/file%20" + index + ".txt", icon: "text-x-generic"
        }))
        property bool loading: false
        property bool dragging: false
        property string error: ""
        property string opened: ""
        property string activeFolder: ""
        readonly property string currentFolder: activeFolder
        property bool canNavigateUp: false
        property string defaultFolder: ""
        property var folderAliases: ({})
        property var folders: ["/tmp/folder"]
        property var pinnedFiles: []
        property bool showingPinned: false
        readonly property string activeTab: showingPinned ? "pinned" : activeFolder ? "folder" : "recent"
        property string defaultTab: "recent"
        function beginPanel() {}
        function endPanel() {}
        function beginDrag() { dragging = true }
        function endDrag() { dragging = false }
        function openFile(file) { opened = file.uri }
        function isPinned(uri) { return pinnedFiles.some(file => file.uri === uri) }
        function togglePin(file) { pinnedFiles = isPinned(file.uri)
            ? pinnedFiles.filter(entry => entry.uri !== file.uri) : pinnedFiles.concat([file]) }
        function selectPinned() { activeFolder = ""; showingPinned = true; files = pinnedFiles }
        function refresh() { files = files.map(file => Object.assign({}, file)) }
        function selectFolder(path) { activeFolder = path }
        function setDefaultTab(tab, path = "") { defaultTab = tab; defaultFolder = tab === "folder" ? path : "" }
        function folderLabel(path) { return folderAliases[path] || path.split("/").pop() }
        function setFolderAlias(path, name) { folderAliases = Object.assign({}, folderAliases, {[path]: name}); return true }
    }
    Test.TestCase { id: mouse; when: false }
    FloatingWindow {
        visible: true
        implicitWidth: 500; implicitHeight: 650
        color: Theme.background
        RecentFilesTooltip { id: panel; fileService: backend; x: 20; y: 20 }
    }
    Timer {
        interval: 150; repeat: true; running: true
        onTriggered: {
            if (root.step === 0) {
                root.click(0)
                root.click(2, Qt.ControlModifier)
                root.check(panel.selectedUris.length === 2 && root.row(0).selected && root.row(2).selected
                    && backend.opened === "", "Ctrl-click adds a file without opening it")
                panel.dragSource.prepare(panel.dragFilesFor(backend.files[2].uri), backend.activeTab)
                root.check(panel.dragSource.Drag.mimeData["text/uri-list"] === [backend.files[0], backend.files[2]]
                    .map(file => file.uri + "\r\n").join(""), "drag supplies every selected URI in displayed order")
                mouse.mouseDoubleClickSequence(root.row(2), undefined, undefined, Qt.LeftButton, Qt.ControlModifier)
                root.check(panel.selectedUris.length === 1 && !root.row(2).selected, "repeated Ctrl-click toggles without opening on a double-click event")
                root.click(0)
                root.click(3, Qt.ShiftModifier)
                root.check(panel.selectedUris.length === 4 && panel.selectedUris.includes(backend.files[1].uri),
                    "Shift-click selects an inclusive range")
                root.click(1, Qt.ShiftModifier)
                root.check(panel.selectedUris.length === 2, "reversing a Shift range retains its anchor")
                root.click(3, Qt.ControlModifier)
                root.click(2, Qt.ControlModifier | Qt.ShiftModifier)
                root.check(panel.selectedUris.length === 4, "Ctrl+Shift adds a range to existing files")
                const refresh = mouse.findChild(panel, "refreshFiles") as Item
                mouse.mouseClick(refresh)
            } else if (root.step === 1) {
                root.check(panel.selectedUris.length === 4 && root.row(3).selected, "refresh preserves selection by URI")
                const source = root.row(1)
                root.expectedPayload = panel.selectedFiles.map(file => file.uri + "\r\n").join("")
                panel.dragSource.Drag.dragStarted.connect(() => { root.nativePayload = panel.dragSource.Drag.mimeData["text/uri-list"] })
                mouse.mouseDrag(source, source.width / 2, source.height / 2, 30, 0)
                panel.prepareDrag(backend.files[1].uri, Qt.NoModifier)
                root.check(panel.selectedUris.length === 4, "dragging a selected row preserves the group")
                panel.prepareDrag(backend.files[5].uri, Qt.NoModifier)
                root.check(panel.selectedUris.length === 1 && panel.selectedUris[0] === backend.files[5].uri,
                    "dragging an unselected row selects it alone")
                backend.files = backend.files.slice(0, 5)
            } else if (root.step === 2) {
                root.check(root.nativePayload === root.expectedPayload && !backend.dragging, "native drag starts with the group and balances drag lifecycle")
                root.check(panel.selectedUris.length === 0, "files missing after refresh are removed from selection")
                root.click(0)
                mouse.keyClick(Qt.Key_A, Qt.ControlModifier)
                root.check(panel.selectedUris.length === 5, "Ctrl+A selects the active list")
                mouse.keyClick(Qt.Key_Escape)
                root.check(panel.selectedUris.length === 0, "Escape clears the selection")
                root.click(1)
                backend.activeFolder = backend.folders[0]
            } else if (root.step === 3) {
                root.check(panel.selectedUris.length === 0, "switching tabs clears selection")
                root.click(1, Qt.ShiftModifier)
                root.check(panel.selectedUris.length === 1, "Shift-click without an anchor selects one file")
                console.log(root.failed ? "RECENT FILES FAIL: selection" : "PASS: recent-file multiple selection, ranges, grouped URI payload, refresh preservation, keyboard shortcuts and tab reset")
                Qt.quit()
            }
            root.step++
        }
    }
}
