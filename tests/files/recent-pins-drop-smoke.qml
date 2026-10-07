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
    readonly property string folder: Quickshell.env("RECENT_FILES_TEST_FOLDER")
    property int step: 0
    property int ticks: 0
    property bool failed: false
    property var pendingDrop: null
    readonly property UI.TabBar tabs: mouse.findChild(panel, "recentFilesTabs") as UI.TabBar
    readonly property DropArea listDrop: mouse.findChild(panel, "pinnedFilesDrop") as DropArea
    function uri(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/") }
    function check(ok, message) {
        if (ok) return
        failed = true
        console.error("RECENT FILES FAIL:", message)
    }
    function finish() {
        console.log(failed ? "RECENT FILES FAIL: drops" : "PASS: recent-file pin drops")
        Qt.quit()
    }
    function enter(target, urls) {
        check(target.enabled, "pin drop target is enabled")
        // Drag.Internal has no URL MIME payload. Exercise the native-event adapter
        // with a file-manager-style payload without starting a desktop drag.
        pendingDrop = {hasUrls: true, urls: urls, supportedActions: Qt.CopyAction,
            accepted: false, action: Qt.IgnoreAction,
            accept: function(action) { this.action = action; this.accepted = true }}
        panel.acceptPinDrag(pendingDrop)
    }
    function drop() {
        check(pendingDrop.accepted, "file drag is accepted on entry")
        panel.pinDrop(pendingDrop)
        check(pendingDrop.accepted && pendingDrop.action === Qt.CopyAction, "pin drop accepts CopyAction")
    }
    Test.TestCase { id: mouse; parent: testWindow.contentItem; when: false }
    FloatingWindow {
        id: testWindow
        visible: true
        implicitWidth: 500
        implicitHeight: 650
        color: Theme.background
        RecentFilesTooltip { id: panel; x: 20; y: 20 }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (++root.ticks > 80) { root.check(false, "drop timeout at step " + root.step); root.finish(); return }
            if (RecentFilesService.loading || PinnedFilesService.checking || PinnedFilesService.importing) return
            if (root.step === 0) {
                root.check(root.tabs.count === 1, "Pinned stays hidden until the first pin")
                root.check(root.tabs.dropEnabledTabs.every(enabled => !enabled) && !root.listDrop.enabled,
                    "Recent does not accept pin drops")
                RecentFilesService.togglePin(RecentFilesService.files[0])
            } else if (root.step === 1) {
                root.enter(root.tabs.itemAt(1), [root.uri(root.folder + "/item01.txt"), root.uri(root.folder + "/item01.txt")])
            } else if (root.step === 2) {
                root.check(root.tabs.dropEnabledTabs[1], "Pinned header is configured as a drop target")
                root.drop()
            } else if (root.step === 3) {
                root.check(RecentFilesService.pinnedFiles.length === 2 && root.tabs.currentIndex === 0
                    && !RecentFilesService.showingPinned, "header drop pins a file once without switching tabs")
                RecentFilesService.selectPinned()
            } else if (root.step === 4) {
                root.enter(root.listDrop, [root.uri(root.folder + "/item02.txt"), root.uri(root.folder + "/item03.txt"),
                    root.uri(root.folder), root.uri(root.folder + "/missing.txt"), "https://example.com/file.txt",
                    "file://remote/tmp/file.txt", "file:///tmp/%00", "file:///tmp/%XX"])
            } else if (root.step === 5) {
                root.check(root.pendingDrop.accepted, "Pinned list accepts a local-file drag")
                // Match the service's native source-drag lifecycle without starting a desktop drag.
                RecentFilesService.beginDrag()
                root.drop()
                RecentFilesService.pinUrls([root.uri(root.folder + "/item04.txt")])
            } else if (root.step === 6) {
                root.check(RecentFilesService.pinnedFiles.length === 2, "imports preserve the source model until drag completion")
                RecentFilesService.endDrag()
            } else if (root.step === 7) {
                root.check(RecentFilesService.pinnedFiles.length === 5 && RecentFilesService.files.length === 5
                    && RecentFilesService.pinnedFiles.every(file => !file.isDirectory),
                    "multiple and queued drops pin readable local files while skipping invalid entries")
                root.enter(root.listDrop, ["https://example.com/file.txt", "file://remote/tmp/file.txt"])
            } else if (root.step === 8) {
                root.check(!root.pendingDrop.accepted, "remote-only drags are rejected")
                panel.pinDrop(root.pendingDrop)
                root.check(!root.pendingDrop.accepted, "remote-only drops are rejected")
                for (const file of RecentFilesService.pinnedFiles.slice()) RecentFilesService.togglePin(file)
            } else if (root.step === 9) {
                root.check(root.tabs.count === 1 && RecentFilesService.pinnedFiles.length === 0,
                    "removing dropped pins restores the conditional tab")
                root.finish(); return
            }
            root.step++
        }
    }
}
