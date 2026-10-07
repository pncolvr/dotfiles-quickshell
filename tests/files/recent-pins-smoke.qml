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
    readonly property string phase: Quickshell.env("RECENT_PINS_TEST_PHASE")
    readonly property string folder: Quickshell.env("RECENT_FILES_TEST_FOLDER")
    readonly property string recentPath: Quickshell.env("RECENT_FILES_TEST_FILE")
    readonly property string pinnedPath: Quickshell.env("RECENT_FILES_TEST_PINNED_FILE")
    property int step: 0
    property int ticks: 0
    property bool failed: false
    readonly property ListView list: mouse.findChild(panel, "recentFilesList") as ListView
    readonly property UI.TabBar tabs: mouse.findChild(panel, "recentFilesTabs") as UI.TabBar
    readonly property UI.ActionButton defaultStar: mouse.findChild(panel, "setDefaultTab") as UI.ActionButton
    function check(ok, message) {
        if (ok) return
        failed = true
        console.error("RECENT FILES FAIL:", message)
    }
    function finish() {
        console.log(failed ? "RECENT FILES FAIL: pins " + phase : "PASS: recent-file pinned tab " + phase)
        Qt.quit()
    }
    function clickTab(index) {
        const tab = tabs.itemAt(index)
        mouse.mouseClick(tab, tab.width / 2, tab.height / 2)
    }
    function rowFor(path) {
        const index = RecentFilesService.files.findIndex(file => file.path === path)
        if (index < 0) { check(false, "file row exists: " + path); return null }
        list.positionViewAtIndex(index, ListView.Contain)
        list.forceLayout()
        return list.itemAtIndex(index) as RecentFileRow
    }
    function clickPin(path) {
        const row = rowFor(path)
        if (!row) { check(false, "pin row is instantiated"); return }
        const button = mouse.findChild(row, "pinFile") as QC.Button
        mouse.mouseClick(button, button.width / 2, button.height / 2)
    }
    Test.TestCase { id: mouse; parent: testWindow.contentItem; when: false }
    Process {
        id: deleteFile
        command: ["rm", "--", root.pinnedPath]
        // qmllint disable signal-handler-parameters
        onExited: exitCode => root.check(exitCode === 0, "delete only the private pinned-file fixture")
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
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (++root.ticks > 80) { root.check(false, "pins timeout at step " + root.step); root.finish(); return }
            if (RecentFilesService.loading || PinnedFilesService.checking || deleteFile.running) return
            if (root.phase === "empty") {
                root.check(RecentFilesService.pinnedFiles.length === 0 && root.tabs.count === 1
                    && !RecentFilesService.showingPinned && PreferencesRepository.value("files.pinned", []).length === 0,
                    "unpins and deletion cleanup persist and the empty Pinned tab stays hidden after restart")
                root.check(RecentFilesService.defaultTab === "recent" && root.defaultStar.foreground === Theme.accent,
                    "Recent default persists after deletion removes the Pinned default")
                root.finish(); return
            }
            if (root.phase === "recent-default") {
                if (root.step === 0) {
                    root.check(RecentFilesService.defaultTab === "recent" && !RecentFilesService.showingPinned
                        && root.tabs.currentIndex === 0 && root.defaultStar.foreground === Theme.accent,
                        "manually chosen Recent survives restart and highlights its star")
                    root.clickTab(1)
                } else if (root.step === 1) {
                    root.check(root.defaultStar.foreground === Theme.text, "Pinned star is neutral while Recent is default")
                    mouse.mouseClick(root.defaultStar, root.defaultStar.width / 2, root.defaultStar.height / 2)
                } else if (root.step === 2) {
                    root.check(RecentFilesService.defaultTab === "pinned" && root.defaultStar.foreground === Theme.accent,
                        "Pinned can replace Recent as default with an accent star")
                    root.finish(); return
                }
                root.step++; return
            }
            if (root.phase === "seed") {
                if (root.step === 0) {
                    root.check(root.tabs.count === 1 && RecentFilesService.pinnedFiles.length === 0, "no empty Pinned tab")
                    const row = root.rowFor(root.recentPath)
                    const name = mouse.findChild(row, "fileName") as Item
                    const tooltip = mouse.findChild(row, "fileNameTooltip") as UI.HoverTooltip
                    root.check(tooltip.text === row.file.name && tooltip.hoverTarget !== null,
                        "filename tooltip contains the complete filename without covering pointer input")
                    mouse.mouseClick(name, name.width / 2, name.height / 2)
                    root.check(panel.selectedUris.length === 1, "clicking a filename still selects its file")
                    root.clickPin(root.recentPath)
                } else if (root.step === 1) {
                    root.check(RecentFilesService.pinnedFiles.length === 1 && root.tabs.count === 2
                        && (root.tabs.itemAt(1) as QC.TabButton).text === "Pinned" && root.tabs.currentIndex === 0
                        && panel.selectedUris.length === 1, "first pin adds Pinned without switching tabs or clearing selection")
                    const row = root.rowFor(root.recentPath)
                    const button = mouse.findChild(row, "pinFile") as UI.ActionButton
                    root.check(row.pinned && button.foreground === Theme.accent && button.hint === "Unpin file",
                        "pinned rows indicate their state and offer unpinning")
                    root.clickTab(1)
                } else if (root.step === 2) {
                    root.check(RecentFilesService.showingPinned && root.list.count === 1 && panel.selectedUris.length === 0,
                        "Pinned displays files and switching from Recent clears selection")
                    RecentFilesService.addFolder(root.folder)
                } else if (root.step === 3) {
                    root.check(!RecentFilesService.showingPinned && RecentFilesService.activeFolder === root.folder
                        && root.tabs.currentIndex === 2 && root.tabs.count === 3,
                        "adding a folder leaves Pinned and highlights its folder tab")
                    const directory = root.list.itemAtIndex(0) as RecentFileRow
                    root.check(directory.file.isDirectory && !mouse.findChild(directory, "pinFile").visible,
                        "directory rows do not offer document pins")
                    const row = root.rowFor(root.pinnedPath)
                    panel.selectFile(row.file.uri, Qt.NoModifier)
                    root.clickPin(root.pinnedPath)
                } else if (root.step === 4) {
                    root.check(RecentFilesService.pinnedFiles.length === 2 && root.tabs.currentIndex === 2
                        && panel.selectedUris.length === 1, "folder pin shares the independent list without changing the active tab")
                    const remove = mouse.findChild(panel, "removeFolderTab") as QC.Button
                    mouse.mouseClick(remove, remove.width / 2, remove.height / 2)
                } else if (root.step === 5) {
                    root.check(RecentFilesService.folders.length === 0 && RecentFilesService.pinnedFiles.length === 2
                        && root.tabs.count === 2 && root.tabs.currentIndex === 0,
                        "removing the source folder tab preserves both document pins")
                    RecentFilesService.refresh()
                    root.clickTab(1)
                } else if (root.step === 6) {
                    root.check(RecentFilesService.showingPinned && root.list.count === 2
                        && RecentFilesService.files.every(file => RecentFilesService.isPinned(file.uri)),
                        "an in-flight Recent scan cannot overwrite Pinned")
                    const row = root.rowFor(root.pinnedPath)
                    panel.selectFile(row.file.uri, Qt.NoModifier)
                    mouse.keyClick(Qt.Key_A, Qt.ControlModifier)
                    panel.dragSource.prepare(panel.dragFilesFor(row.file.uri), RecentFilesService.activeTab)
                    root.check(panel.selectedUris.length === 2 && panel.dragSource.Drag.mimeData["text/uri-list"]
                        === panel.selectedFiles.map(file => file.uri + "\r\n").join(""),
                        "Pinned reuses multiple selection and grouped file drag payloads")
                    root.clickPin(root.recentPath)
                } else if (root.step === 7) {
                    root.check(RecentFilesService.pinnedFiles.length === 1 && RecentFilesService.showingPinned
                        && root.list.count === 1 && panel.selectedUris.length === 1,
                        "manual unpin removes only its entry and preserves remaining selection")
                    root.clickTab(0)
                } else if (root.step === 8) {
                    root.check(!root.rowFor(root.recentPath).pinned, "unpin state is shared with Recent")
                    root.clickPin(root.recentPath)
                } else if (root.step === 9) {
                    root.check(RecentFilesService.pinnedFiles.length === 2
                        && PreferencesRepository.value("files.pinned", []).length === 2
                        && RecentFilesService.folders.length === 0, "pins persist independently from removed folder preferences")
                    root.clickTab(1)
                } else if (root.step === 10) {
                    mouse.mouseClick(root.defaultStar, root.defaultStar.width / 2, root.defaultStar.height / 2)
                    root.check(RecentFilesService.defaultTab === "pinned" && root.defaultStar.foreground === Theme.accent,
                        "Pinned is manually selectable as default and its icon uses accent color")
                    root.clickTab(0)
                } else if (root.step === 11) {
                    root.check(root.defaultStar.foreground === Theme.text, "Recent is neutral while Pinned is default")
                    mouse.mouseClick(root.defaultStar, root.defaultStar.width / 2, root.defaultStar.height / 2)
                    root.check(RecentFilesService.defaultTab === "recent" && root.defaultStar.foreground === Theme.accent
                        && PreferencesRepository.value("files.defaultTab", "") === "recent",
                        "Recent can be explicitly made default and highlights its own icon")
                    root.finish(); return
                }
            } else if (root.phase === "restart") {
                if (root.step === 0) {
                    root.check(RecentFilesService.pinnedFiles.length === 2 && root.tabs.count === 2
                        && RecentFilesService.folders.length === 0 && root.list.count === 2
                        && RecentFilesService.showingPinned && RecentFilesService.defaultTab === "pinned"
                        && root.tabs.currentIndex === 1 && root.defaultStar.foreground === Theme.accent,
                        "Pinned default survives restart, removed folder tabs and an empty desktop history")
                    root.clickTab(0)
                } else if (root.step === 1) {
                    root.check(root.list.count === 0 && !RecentFilesService.showingPinned
                        && root.defaultStar.foreground === Theme.text, "empty Recent remains selectable with a Pinned default")
                    root.clickTab(1)
                } else if (root.step === 2) {
                    root.check(RecentFilesService.showingPinned && root.list.count === 2,
                        "Pinned includes documents absent from Recent and folder tabs")
                    root.clickPin(root.recentPath)
                } else if (root.step === 3) {
                    root.check(RecentFilesService.pinnedFiles.length === 1 && RecentFilesService.showingPinned,
                        "manual unpin after restart preserves the remaining pin")
                    const row = root.rowFor(root.pinnedPath)
                    panel.selectFile(row.file.uri, Qt.NoModifier)
                    deleteFile.running = true
                } else if (root.step === 4) {
                    PinnedFilesService.refresh()
                    RecentFilesService.beginDrag()
                } else if (root.step === 5) {
                    root.check(RecentFilesService.pinnedFiles.length === 1 && root.list.count === 1
                        && panel.selectedUris.length === 1, "deleted-file cleanup is deferred until the drag finishes")
                    RecentFilesService.endDrag()
                } else if (root.step === 6) {
                    root.check(RecentFilesService.pinnedFiles.length === 0 && root.tabs.count === 1
                        && root.tabs.currentIndex === 0 && !RecentFilesService.showingPinned && root.list.count === 0
                        && panel.selectedUris.length === 0 && RecentFilesService.error === "",
                        "deleting the last pinned file hides Pinned and falls back to Recent without stale selection")
                    root.check(RecentFilesService.defaultTab === "recent" && root.defaultStar.foreground === Theme.accent
                        && PreferencesRepository.value("files.defaultTab", "") === "recent",
                        "removing the last pin resets the default to Recent and highlights its star")
                    root.finish(); return
                }
            } else { root.check(false, "unknown test phase"); root.finish(); return }
            root.step++
        }
    }
}
