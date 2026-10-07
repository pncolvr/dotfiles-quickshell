pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import QtQuick.Dialogs as Dialogs
import QtTest as Test
import Quickshell
import Quickshell.Io
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
    Test.TestCase { id: mouse; parent: testWindow.contentItem; when: false }
    Process {
        id: addFile
        command: ["touch", "-m", "-d", "@" + (Math.floor(Date.now() / 1000) + 200), root.folder + "/refreshed.txt"]
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: exitCode => root.check(exitCode === 0, "private refresh fixture creates a new file")
        // qmllint enable signal-handler-parameters
    }
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
                root.check(RecentFilesService.activeFolder === (root.phase === "restart" ? root.folder : "")
                    && tabs.currentIndex === (root.phase === "restart" ? 1 : 0), "launch selects the saved default or Recent")
                root.check(!mouse.findChild(tabs.itemAt(0), "tabCloseButton").visible, "Recent has no delete button")
                root.check(mouse.findChild(tabs.itemAt(0), "tabActionButton") === null, "tabs have no folder-default button")
                if (root.phase === "empty") {
                    root.check(RecentFilesService.folders.length === 0 && tabs.count === 1 && RecentFilesService.defaultFolder === ""
                        && Object.keys(RecentFilesService.folderAliases).length === 0,
                        "removed folder tabs, aliases, and default stay removed after restart")
                    root.finish(); return
                }
                if (root.phase === "restart") {
                    root.check(RecentFilesService.folders.length === 1 && RecentFilesService.folders[0] === root.folder,
                        "folder tab survives restarting the shell")
                    root.check(RecentFilesService.defaultFolder === root.folder && (tabs.itemAt(1) as QC.TabButton).text === "Work docs",
                        "default folder and tab alias survive restarting the shell")
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
                    testWindow.contentItem.Window.window.requestActivate()
                } else if (root.step === 3) {
                    root.check(RecentFilesService.folders.length === 1 && RecentFilesService.activeFolder === root.folder,
                        "picker adds and selects a folder tab")
                    root.check(RecentFilesService.error === "" && list.count === 26 && tabs.count === 2 && tabs.currentIndex === 1,
                        "folder lists all files and directories and its tab is highlighted")
                    root.check(RecentFilesService.files[0]?.isDirectory && RecentFilesService.files[1]?.name === "item24.txt",
                        "directories precede files and the newest file comes first in its group")
                    root.check(root.panel.height <= root.panel.maxPanelHeight, "folder controls leave a bounded list")
                    const close = mouse.findChild(tabs.itemAt(1), "tabCloseButton") as QC.Button
                    root.check(!close.visible, "folder tab has no close button")
                    const remove = root.child("removeFolderTab") as UI.ActionButton
                    root.check(remove.visible && remove.glyph === Theme.deleteIcon && remove.fillColor === Theme.urgent,
                        "folder removal uses a red trash button in the panel")
                } else if (root.step === 4) {
                    root.check(RecentFilesService.files.every((file, index, files) => index === 0
                        || (files[index - 1].isDirectory === file.isDirectory
                            ? files[index - 1].usedAt >= file.usedAt : files[index - 1].isDirectory)),
                        "folders are first, with descending recency within each group")
                    const row = list.itemAtIndex(1) as RecentFileRow
                    root.check(row.Drag.mimeData["text/uri-list"] === RecentFilesService.files[1].uri + "\r\n",
                        "folder files use the existing native file drag payload")
                    const screenshot = Quickshell.env("RECENT_FOLDERS_TEST_SCREENSHOT")
                    if (screenshot) root.panel.grabToImage(result => result.saveToFile(screenshot))
                    mouse.mouseClick(row, row.width / 2, row.height / 2)
                    addFile.running = true
                } else if (root.step === 5) {
                    if (addFile.running) return
                    const refresh = root.child("refreshFiles") as QC.Button
                    mouse.mouseClick(refresh, refresh.width / 2, refresh.height / 2)
                } else if (root.step === 6) {
                    root.check(RecentFilesService.activeFolder === root.folder && tabs.currentIndex === 1
                        && RecentFilesService.files[0]?.isDirectory && RecentFilesService.files[1]?.name === "refreshed.txt" && list.count === 27,
                        "refresh rescans the current folder and preserves its tab")
                    root.check(root.panel.selectedFiles[0]?.name === "item24.txt", "folder refresh preserves selected files across reordering")
                    RecentFilesService.addFolder(Quickshell.env("RECENT_FILES_TEST_FOLDER_ALIAS"))
                } else if (root.step === 7) {
                    root.check(RecentFilesService.folders.length === 1, "folder aliases do not duplicate tabs")
                    const star = root.child("setDefaultFolder") as QC.Button
                    mouse.mouseClick(star, star.width / 2, star.height / 2)
                    root.check(RecentFilesService.defaultFolder === root.folder, "star sets the folder as default")
                    root.panel.destroy()
                    root.panel = null
                } else if (root.step === 8) {
                    root.panel = panelFactory.createObject(testWindow.contentItem, {x: 20, y: 20})
                } else if (root.step === 9) {
                    root.check(RecentFilesService.activeFolder === root.folder && tabs.currentIndex === 1 && list.count === 27,
                        "reopening selects the saved default folder")
                    const recent = tabs.itemAt(0)
                    mouse.mouseClick(recent, recent.width / 2, recent.height / 2)
                } else if (root.step === 10) {
                    root.check(RecentFilesService.activeFolder === "", "Recent remains selectable with a default folder")
                    root.check(!root.child("editFolderAlias").visible && !root.child("setDefaultFolder").visible
                        && !root.child("removeFolderTab").visible,
                        "folder actions are hidden on Recent")
                    const folderTab = tabs.itemAt(1)
                    root.check(mouse.findChild(folderTab, "tabActionButton") === null,
                        "folder tabs have no action buttons")
                    mouse.mouseClick(folderTab, 5, folderTab.height / 2)
                } else if (root.step === 11) {
                    const edit = root.child("editFolderAlias") as QC.Button
                    root.check(edit.visible && root.child("setDefaultFolder").visible, "folder actions are on the active folder panel")
                    mouse.mouseClick(edit, edit.width / 2, edit.height / 2)
                } else if (root.step === 12) {
                    const input = root.child("folderAliasInput") as QC.TextField
                    root.check(root.panel.renameFolder === root.folder && input.visible, "panel edit button opens the folder alias editor")
                    root.check(root.panel.height <= root.panel.maxPanelHeight, "alias editor leaves a bounded file list")
                } else if (root.step === 13) {
                    const cancel = root.child("cancelFolderAlias") as UI.ActionButton
                    const save = root.child("saveFolderAlias") as UI.ActionButton
                    root.check(cancel.mapToItem(root.panel, 0, 0).x < save.mapToItem(root.panel, 0, 0).x
                        && save.fillColor === Theme.accent && cancel.fillColor === Theme.alternateBackground,
                        "editor uses neutral Cancel before accent Apply")
                    const input = root.child("folderAliasInput") as QC.TextField
                    input.text = "Cancel this draft"
                    mouse.mouseClick(cancel, cancel.width / 2, cancel.height / 2)
                    root.check(root.panel.renameFolder === "" && RecentFilesService.folderAliases[root.folder] === undefined,
                        "Cancel discards the alias draft")
                    const edit = root.child("editFolderAlias") as QC.Button
                    mouse.mouseClick(edit, edit.width / 2, edit.height / 2)
                } else if (root.step === 14) {
                    const input = root.child("folderAliasInput") as QC.TextField
                    input.text = "Escape this draft"
                    input.forceActiveFocus()
                    mouse.keyClick(Qt.Key_Escape)
                    root.check(root.panel.renameFolder === "" && RecentFilesService.folderAliases[root.folder] === undefined,
                        "Escape discards the alias draft")
                    const edit = root.child("editFolderAlias") as QC.Button
                    mouse.mouseClick(edit, edit.width / 2, edit.height / 2)
                } else if (root.step === 15) {
                    const input = root.child("folderAliasInput") as QC.TextField
                    input.text = "  Work docs  "
                    const save = root.child("saveFolderAlias") as UI.ActionButton
                    mouse.mouseClick(save, save.width / 2, save.height / 2)
                } else if (root.step === 16) {
                    root.check((tabs.itemAt(1) as QC.TabButton).text === "Work docs" && RecentFilesService.folderAliases[root.folder] === "Work docs"
                        && RecentFilesService.activeFolder === root.folder && RecentFilesService.defaultFolder === root.folder
                        && root.panel.renameFolder === "", "saving an alias changes only the tab label")
                    const star = root.child("setDefaultFolder") as QC.Button
                    mouse.mouseClick(star, star.width / 2, star.height / 2)
                    root.check(RecentFilesService.defaultFolder === "", "clicking the default star resets it to Recent")
                } else if (root.step === 17) {
                    const star = root.child("setDefaultFolder") as QC.Button
                    mouse.mouseClick(star, star.width / 2, star.height / 2)
                    root.finish(); return
                }
            } else if (root.phase === "restart") {
                if (root.step === 1) {
                    root.check(tabs.count === 3 && tabs.currentIndex === 2 && RecentFilesService.activeFolder === root.secondFolder,
                        "second folder gets its own selected tab")
                    const star = root.child("setDefaultFolder") as QC.Button
                    mouse.mouseClick(star, star.width / 2, star.height / 2)
                    root.check(RecentFilesService.defaultFolder === root.secondFolder, "another folder can replace the default")
                    const firstTab = tabs.itemAt(1)
                    mouse.mouseClick(firstTab, 5, firstTab.height / 2)
                } else if (root.step === 2) {
                    root.check(RecentFilesService.activeFolder === root.folder && tabs.currentIndex === 1,
                        "selecting a folder targets its panel actions")
                    root.panel.editFolderName(root.folder)
                    const remove = root.child("removeFolderTab") as QC.Button
                    mouse.mouseClick(remove, remove.width / 2, remove.height / 2)
                } else if (root.step === 3) {
                    root.check(RecentFilesService.folders.length === 1 && RecentFilesService.activeFolder === ""
                        && tabs.currentIndex === 0 && RecentFilesService.defaultFolder === root.secondFolder
                        && root.panel.renameFolder === ""
                        && RecentFilesService.folderAliases[root.folder] === undefined,
                        "panel removal preserves another folder's default, removes the alias, and closes its editor")
                    const secondTab = tabs.itemAt(1)
                    mouse.mouseClick(secondTab, 5, secondTab.height / 2)
                } else if (root.step === 4) {
                    RecentFilesService.setFolderAlias(root.secondFolder, "Second docs")
                    root.panel.editFolderName(root.secondFolder)
                    const input = root.child("folderAliasInput") as QC.TextField
                    input.text = ""
                    input.forceActiveFocus()
                    mouse.keyClick(Qt.Key_Return)
                    root.check(RecentFilesService.folderLabel(root.secondFolder) === "folder two" && root.panel.renameFolder === "",
                        "saving a blank alias with Enter restores the folder name")
                    const remove = root.child("removeFolderTab") as QC.Button
                    mouse.mouseClick(remove, remove.width / 2, remove.height / 2)
                } else if (root.step === 5) {
                    root.check(RecentFilesService.folders.length === 0 && RecentFilesService.activeFolder === ""
                        && tabs.currentIndex === 0 && list.count === 1 && RecentFilesService.defaultFolder === "",
                        "removing the default folder returns to Recent and resets its default")
                    root.finish(); return
                }
            }
            root.step++
        }
    }
}
