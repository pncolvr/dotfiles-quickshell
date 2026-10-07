pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import Quickshell.Io
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
    readonly property ListView list: mouse.findChild(panel, "recentFilesList") as ListView
    readonly property UI.TabBar tabs: mouse.findChild(panel, "recentFilesTabs") as UI.TabBar
    readonly property UI.ActionButton up: mouse.findChild(panel, "navigateFolderUp") as UI.ActionButton
    function check(ok, message) {
        if (ok) return
        failed = true
        console.error("RECENT FILES FAIL:", message)
    }
    function finish() {
        console.log(failed ? "RECENT FILES FAIL: navigation" : "PASS: recent-file unlimited folders, directory navigation, Go up, refresh, stale scans and tab reset")
        Qt.quit()
    }
    function directoryIndex(name) {
        return RecentFilesService.files.findIndex(file => file.isDirectory && file.name === name)
    }
    Test.TestCase { id: mouse; parent: testWindow.contentItem; when: false }
    Process {
        id: addFile
        command: ["touch", root.folder + "/subfolder/new.txt"]
        // qmllint disable signal-handler-parameters
        onExited: exitCode => root.check(exitCode === 0, "create private navigation refresh fixture")
        // qmllint enable signal-handler-parameters
    }
    FloatingWindow {
        id: testWindow
        visible: true
        implicitWidth: 500
        implicitHeight: 650
        color: Theme.background
        RecentFilesTooltip { id: panel; x: 20; y: 20 }
    }
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 80) { root.check(false, "navigation timeout at step " + root.step); root.finish(); return }
            if (RecentFilesService.loading) return
            if (root.step === 0) {
                root.check(RecentFilesService.currentFolder === root.folder && root.list.count === 27 && !root.up.enabled,
                    "saved folder starts with all entries and Go up disabled")
                panel.selectFile(RecentFilesService.files[0].uri, Qt.NoModifier)
                const index = root.directoryIndex("subfolder")
                root.check(index >= 0, "directory is listed")
                root.list.positionViewAtIndex(index, ListView.Contain)
                root.list.forceLayout()
            } else if (root.step === 1) {
                const row = root.list.itemAtIndex(root.directoryIndex("subfolder")) as RecentFileRow
                root.check(row?.file.icon === "inode-directory", "directory uses a folder icon")
                if (!row) { root.finish(); return }
                mouse.mouseDoubleClickSequence(row, row.width / 2, row.height / 2)
            } else if (root.step === 2) {
                root.check(RecentFilesService.currentFolder === root.folder + "/subfolder" && root.list.count === 2
                    && RecentFilesService.activeFolder === root.folder && root.tabs.currentIndex === 1
                    && root.tabs.count === 2 && root.up.enabled && panel.selectedUris.length === 0,
                    "double-click browses a directory in the same tab and clears selection")
                const tooltip = mouse.findChild(panel, "folderPathTooltip") as UI.HoverTooltip
                root.check(tooltip.text === RecentFilesService.currentFolder, "path tooltip follows the browsed folder")
                addFile.running = true
            } else if (root.step === 3) {
                if (addFile.running) return
                const refresh = mouse.findChild(panel, "refreshFiles") as QC.Button
                mouse.mouseClick(refresh, refresh.width / 2, refresh.height / 2)
            } else if (root.step === 4) {
                root.check(RecentFilesService.currentFolder === root.folder + "/subfolder" && root.list.count === 3
                    && RecentFilesService.files.some(file => file.name === "new.txt"), "refresh updates the browsed directory")
                const row = root.list.itemAtIndex(root.directoryIndex("nested")) as RecentFileRow
                if (!row) { root.check(false, "nested folder row is available"); root.finish(); return }
                mouse.mouseDoubleClickSequence(row, row.width / 2, row.height / 2)
            } else if (root.step === 5) {
                root.check(RecentFilesService.currentFolder === root.folder + "/subfolder/nested"
                    && root.list.count === 1 && RecentFilesService.files[0]?.name === "leaf.txt", "nested navigation lists its own files")
                mouse.mouseClick(root.up, root.up.width / 2, root.up.height / 2)
            } else if (root.step === 6) {
                root.check(RecentFilesService.currentFolder === root.folder + "/subfolder" && root.list.count === 3,
                    "Go up returns one directory level")
                mouse.mouseClick(root.up, root.up.width / 2, root.up.height / 2)
            } else if (root.step === 7) {
                root.check(RecentFilesService.currentFolder === root.folder && root.list.count === 27 && !root.up.enabled,
                    "Go up returns to the tab root and disables there")
                RecentFilesService.navigateFolder(root.folder + "/subfolder")
            } else if (root.step === 8) {
                const tab = root.tabs.itemAt(1)
                mouse.mouseClick(tab, 5, tab.height / 2)
            } else if (root.step === 9) {
                root.check(RecentFilesService.currentFolder === root.folder && !root.up.enabled, "clicking the active tab resets navigation")
                RecentFilesService.navigateFolder(root.folder + "/missing")
            } else if (root.step === 10) {
                root.check(RecentFilesService.error.length > 0 && root.up.enabled && root.list.count === 0,
                    "failed navigation can be recovered with Go up")
                mouse.mouseClick(root.up, root.up.width / 2, root.up.height / 2)
            } else if (root.step === 11) {
                root.check(RecentFilesService.error === "" && root.list.count === 27, "Go up recovers from a missing directory")
                RecentFilesService.navigateFolder(root.folder + "/subfolder")
                RecentFilesService.selectFolder("")
            } else if (root.step === 12) {
                root.check(RecentFilesService.currentFolder === "" && root.tabs.currentIndex === 0 && root.list.count === 1
                    && !root.up.visible && RecentFilesService.error === "", "switching to Recent discards stale directory scans")
                RecentFilesService.selectFolder(root.folder)
            } else if (root.step === 13) {
                root.check(RecentFilesService.currentFolder === root.folder && root.list.count === 27 && !root.up.enabled,
                    "returning to the folder tab restores its root")
                RecentFilesService.beginDrag()
                root.check(!RecentFilesService.navigateFolder(root.folder + "/subfolder"), "navigation is blocked while dragging")
                RecentFilesService.endDrag()
                root.check(RecentFilesService.defaultFolder === root.folder && RecentFilesService.folderLabel(root.folder) === "Work docs",
                    "navigation preserves default and alias preferences")
                root.finish(); return
            }
            root.step++
        }
    }
}
