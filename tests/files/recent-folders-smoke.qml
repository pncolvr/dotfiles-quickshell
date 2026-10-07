pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import QtQuick.Dialogs as Dialogs
import QtTest as Test
import Quickshell
import "../../src/modules/system/files"
import "../../src/services"
import "../../src/theme"
import "../../src/theme/ui" as UI

Scope {
    id: root
    readonly property string phase: Quickshell.env("RECENT_FOLDERS_TEST_PHASE")
    readonly property string folder: Quickshell.env("RECENT_FILES_TEST_FOLDER")
    readonly property string secondFolder: Quickshell.env("RECENT_FILES_TEST_SECOND_FOLDER")
    property RecentFilesTooltip panel: null
    property int step: 0
    property int ticks: 0
    property bool failed: false
    function check(ok, message) {
        if (ok) return
        failed = true
        console.error("RECENT FILES FAIL:", message)
    }
    function finish() {
        console.log(failed ? "RECENT FILES FAIL: folders " + phase : "PASS: recent-file folder tabs " + phase)
        Qt.quit()
    }
    function child(name) { return mouse.findChild(panel, name) }
    Test.TestCase { id: mouse; when: false }
    Component { id: panelFactory; RecentFilesTooltip {} }
    FloatingWindow {
        id: testWindow
        visible: true
        implicitWidth: 500
        implicitHeight: 650
        color: Theme.background
        Component.onCompleted: root.panel = panelFactory.createObject(contentItem, {x: 20, y: 20})
    }
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 70) { root.check(false, "folder test timeout at step " + root.step); root.finish(); return }
            if (RecentFilesService.loading) return
            const tabs = root.child("recentFilesTabs") as UI.TabBar
            const list = root.child("recentFilesList") as ListView
            if (root.step === 0) {
                root.check(RecentFilesService.activeFolder === "" && tabs.currentIndex === 0, "Recent is the default on every launch")
                root.check(!mouse.findChild(tabs.itemAt(0), "tabCloseButton").visible, "Recent has no delete button")
                if (root.phase === "empty") {
                    root.check(RecentFilesService.folders.length === 0 && tabs.count === 1, "removed folder tabs stay removed after restart")
                    root.finish(); return
                }
                if (root.phase === "restart") {
                    root.check(RecentFilesService.folders.length === 1 && RecentFilesService.folders[0] === root.folder,
                        "folder tab survives restarting the shell")
                    RecentFilesService.addFolder(root.secondFolder)
                } else {
                    root.check(RecentFilesService.folders.length === 0, "private test database starts empty")
                    RecentFilesService.addFolder(root.folder + "/missing")
                }
            } else if (root.phase === "seed") {
                if (root.step === 1) {
                    root.check(RecentFilesService.error.length > 0 && RecentFilesService.folders.length === 0,
                        "invalid folder is not saved")
                    root.panel.folderPicker.options = Dialogs.FolderDialog.ReadOnly | Dialogs.FolderDialog.DontUseNativeDialog
                    root.panel.folderPicker.currentFolder = "file://" + root.folder
                    const add = root.child("addFolderTab") as QC.Button
                    mouse.mouseClick(add, add.width / 2, add.height / 2)
                    root.check(root.panel.folderPicker.visible, "far-right plus opens the directory picker")
                } else if (root.step === 2) {
                    root.panel.folderPicker.selectedFolder = "file://" + root.folder
                    root.panel.folderPicker.accept()
                } else if (root.step === 3) {
                    root.check(RecentFilesService.folders.length === 1 && RecentFilesService.activeFolder === root.folder,
                        "picker adds and selects a folder tab")
                    root.check(RecentFilesService.error === "" && list.count === 20 && tabs.count === 2 && tabs.currentIndex === 1,
                        "folder list is capped and its tab is highlighted")
                    root.check(RecentFilesService.files[0]?.name === "item24.txt", "modified order puts newest file first")
                    root.check(root.panel.height <= root.panel.maxPanelHeight, "folder controls leave a bounded list")
                    const close = mouse.findChild(tabs.itemAt(1), "tabCloseButton") as QC.Button
                    root.check(close.visible && close.width <= 16, "folder tab has a small close button")
                } else if (root.step === 4) {
                    root.check(RecentFilesService.files.every((file, index, files) => index === 0 || files[index - 1].usedAt >= file.usedAt),
                        "folder recency order is descending")
                    const row = list.itemAtIndex(0) as RecentFileRow
                    root.check(row.Drag.mimeData["text/uri-list"] === RecentFilesService.files[0].uri + "\r\n",
                        "folder files use the existing native file drag payload")
                    const screenshot = Quickshell.env("RECENT_FOLDERS_TEST_SCREENSHOT")
                    if (screenshot) root.panel.grabToImage(result => result.saveToFile(screenshot))
                    RecentFilesService.addFolder(Quickshell.env("RECENT_FILES_TEST_FOLDER_ALIAS"))
                } else if (root.step === 5) {
                    root.check(RecentFilesService.folders.length === 1, "folder aliases do not duplicate tabs")
                    root.panel.destroy()
                    root.panel = null
                } else if (root.step === 6) {
                    root.panel = panelFactory.createObject(testWindow.contentItem, {x: 20, y: 20})
                } else if (root.step === 7) {
                    root.check(RecentFilesService.activeFolder === "" && tabs.currentIndex === 0 && list.count === 1,
                        "reopening defaults to Recent even after selecting a folder")
                    root.finish(); return
                }
            } else if (root.phase === "restart") {
                if (root.step === 1) {
                    root.check(tabs.count === 3 && tabs.currentIndex === 2 && RecentFilesService.activeFolder === root.secondFolder,
                        "second folder gets its own selected tab")
                    const close = mouse.findChild(tabs.itemAt(1), "tabCloseButton") as QC.Button
                    mouse.mouseClick(close, close.width / 2, close.height / 2)
                } else if (root.step === 2) {
                    root.check(RecentFilesService.folders.length === 1 && RecentFilesService.activeFolder === root.secondFolder
                        && tabs.currentIndex === 1, "removing another tab preserves the selected folder")
                    const close = mouse.findChild(tabs.itemAt(1), "tabCloseButton") as QC.Button
                    mouse.mouseClick(close, close.width / 2, close.height / 2)
                } else if (root.step === 3) {
                    root.check(RecentFilesService.folders.length === 0 && RecentFilesService.activeFolder === ""
                        && tabs.currentIndex === 0 && list.count === 1, "removing the selected folder returns to Recent")
                    root.finish(); return
                }
            }
            root.step++
        }
    }
}
