pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs as Dialogs
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/launcher"

import "../../src/config"

WorkerScope {
    id: root
    property var testConfig: Config
    readonly property string directory: Quickshell.env("DIRECTORY_TEST_DIR")
    readonly property string folder: directory + "/home/banana folder"
    property int step: 0
    property int ticks: 0
    property bool failed: false
    property bool dispatching: false
    property bool waitingForSave: false
    property bool saveShouldSucceed: true
    Connections {
        target: DirectoryService
        function onSaved(path) { root.waitingForSave = false }
        function onErrorChanged() {
            if (!root.waitingForSave || !DirectoryService.error) return
            root.waitingForSave = false
            if (root.saveShouldSucceed) root.check(false, "save at " + root.step + ": " + DirectoryService.error)
        }
    }
    Test.TestEvent { id: events }
    Test.TestCase { id: waiter; when: false }
    FileView { id: actions; path: root.directory + "/actions"; preload: false; blockLoading: true; printErrors: false }
    FileView { id: resolving; path: root.directory + "/resolving"; preload: false; blockLoading: true; blockWrites: true; printErrors: false }
    function openedPaths() {
        actions.reload()
        return actions.text().trim().split("\n").filter(Boolean).map(line => JSON.parse(line)[0])
    }
    function until(predicate, message) {
        const deadline = Date.now() + 4000
        while (!predicate() && Date.now() < deadline) waiter.wait(10)
        check(predicate(), message)
        if (!predicate()) throw new Error(message)
    }
    function typedQuery(text) {
        PickerService.directories()
        const field = find("pickerSearch")
        until(() => field.activeFocus, "directory search focuses")
        field.text = text
        check(PickerService.filteredItems.length === 0 && PickerService.canAccept, "unmatched path enables typed acceptance: " + text)
        events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
    }
    function typedPaths() {
        const initialEntries = JSON.stringify(DirectoryService.directories)
        const home = Quickshell.env("HOME"), orange = home + "/orange folder"
        for (const [input, expected] of [
            [orange, orange], ["~/orange folder", orange], ["$HOME/orange folder", orange],
            ["${HOME}/orange folder", orange], ["orange folder", orange],
            ["~", home], ["$HOME", home], ["${HOME}", home],
            [directory + "/folder-link", root.folder], ["$DIRECTORY_LITERAL", Quickshell.env("DIRECTORY_LITERAL")]
        ]) {
            const count = openedPaths().length
            typedQuery(input)
            until(() => !PickerService.visible && !DirectoryService.busy && openedPaths().length === count + 1, "typed folder opens: " + input)
            check(openedPaths().slice(-1)[0] === expected, "typed path expands literally and resolves symlinks")
        }
        for (const input of [directory + "/missing", directory + "/plain-file", "$DIRECTORY_UNSET_FIXTURE", "smb://unmatched/typed"]) {
            const count = openedPaths().length
            typedQuery(input)
            until(() => !DirectoryService.busy && !!DirectoryService.error, "invalid folder reports an error")
            check(PickerService.visible && PickerService.query === input && find("pickerSearch").activeFocus, "invalid folder retains query and focus")
            check(PickerService.error === DirectoryService.error && openedPaths().length === count, "invalid folder never launches")
            find("pickerSearch").text = ""
            check(!PickerService.error, "editing clears the error")
        }
        PickerService.directories()
        find("pickerSearch").text = "Banana"
        until(() => find("pickerSearch").activeFocus, "saved matching row remains focused")
        check(PickerService.filteredItems.length === 1, "saved match keeps priority")
        const count = openedPaths().length
        events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
        until(() => openedPaths().length === count + 1, "saved row opens")
        check(openedPaths().slice(-1)[0] === root.folder && !DirectoryService.busy, "saved matches use the existing direct action")
        for (const action of ["edit", "close", "replace"]) {
            const count = openedPaths().length
            resolving.setText("")
            typedQuery("~/slow folder")
            until(() => { resolving.reload(); return resolving.text() === "busy" }, "delayed lookup started")
            switch (action) {
              case "edit": find("pickerSearch").text = "new unmatched path"; break
              case "close": events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0); break
              case "replace": PickerService.promptMenu("Replacement", [{title:"Keep working"}], () => {}); break
            }
            waiter.wait(450)
            check(openedPaths().length === count, "stale lookup cannot open after " + action)
            check(!PickerService.error, "stale lookup cannot replace current error state")
        }
        PickerService.close()
        check(JSON.stringify(DirectoryService.directories) === initialEntries, "typed paths never change saved entries")
        if (!failed) console.log("PASS: directories typed")
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 700
        implicitHeight: panel.implicitHeight
        DirectoryPickerPanel { id: panel; width: parent.width; height: parent.height }
    }
    function find(name, item=panel) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const found=find(name,child); if (found) return found }
        return null
    }
    function check(condition,message) { if (!condition) { failed = true; console.error("DIRECTORY FAIL: " + message) } }
    function save(nextStep, expectSuccess = true) {
        waitingForSave = true
        saveShouldSucceed = expectSuccess
        step = nextStep
        find("saveDirectory").clicked()
    }
    Timer {
        id: ticker
        interval: 80
        repeat: true
        running: !root.dispatching
        onTriggered: {
            if (root.dispatching) return
            root.dispatching = true
            try { ticker.runStep() }
            finally { root.dispatching = false }
        }
        function runStep() {
            if (++root.ticks > 200 || root.failed) { console.error("DIRECTORY FAIL: timeout at " + root.step + ": " + DirectoryService.error); stop(); Qt.quit(); return }
            if (!DbService.ready || DirectoryService.busy || StatusService.status !== "personal") return
            if (root.waitingForSave) return
            if (Quickshell.env("DIRECTORY_TEST_PHASE") === "typed") {
                stop()
                try { root.typedPaths() } catch (error) { root.check(false, String(error)) }
                Qt.quit()
                return
            }
            if (Quickshell.env("DIRECTORY_TEST_PHASE") === "restart") {
                root.check(DirectoryService.directories.length === 2,"directory entries survive restart")
                PickerService.directories()
                root.check(!DirectoryService.managing && !DirectoryService.showAll && PickerService.items.length === 2,"reopening defaults to picker and status filter")
                root.check(DirectoryService.directories.some(entry => entry.path === "trash:///" && entry.name === "Tomato"),"edited system location and name persist")
                PickerService.currentIndex = PickerService.filteredItems.findIndex(entry => entry.result === "trash:///")
                PickerService.accept(false,false)
                root.check(!PickerService.visible,"accept opens location and closes picker")
                if (!root.failed) console.log("PASS: directories restart")
                stop(); Qt.quit(); return
            }
            if (root.step === 0) {
                root.check(DirectoryService.directories.length === 0,"fresh database has no legacy import hook")
                PickerService.directories()
                panel.focusSearch()
                root.step = 1
            } else if (root.step === 1) {
                root.check(events.keyClick(Qt.Key_M,Qt.ControlModifier,0),"Ctrl+M reaches directories")
                root.check(DirectoryService.managing && !root.find("directoryForm").visible && root.find("beginAddDirectory").enabled,"empty Manage offers Add without opening an editor")
                panel.beginAdd()
                root.find("directoryPath").text = "~/banana folder"
                root.find("directoryName").text = "Banana"
                root.save(2)
            } else if (root.step === 2) {
                root.check(DirectoryService.directories.length === 1 && DirectoryService.directories[0].path === root.folder,"local folder saved canonically")
                root.check(!root.find("directoryForm").visible && root.find("beginAddDirectory").visible,"saved folder collapses footer")
                panel.focusSearch()
                root.step = 3
            } else if (root.step === 3) {
                root.check(root.find("directoryManageSearch").activeFocus,"Manage search focused")
                root.check(events.keyClick(Qt.Key_N,Qt.ControlModifier,0),"Ctrl+N reaches Manage")
                root.check(root.find("directoryForm").visible,"Ctrl+N opens Add only in Manage")
                root.find("directoryPath").text = "computer:///"
                root.find("directoryCategory").selected(root.find("directoryCategory").selectedName === "work" ? "personal" : "work")
                root.step = 4
            } else if (root.step === 4) {
                root.check(root.find("directoryPath").activeFocus,"Add focuses path")
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches open path")
                root.check(root.find("directoryPath").selectedText === "computer:///","Ctrl+A selects path text while adding")
                root.save(5)
            } else if (root.step === 5) {
                root.check(DirectoryService.directories.length === 2 && !DirectoryService.draft,"system URI saved without filesystem validation")
                root.check(PickerService.items.length === 1,"work directories hidden outside work")
                root.find("directoryManageSearch").text = "cmptr"
                root.check(panel.managementView.filteredEntries.length === 1 && panel.managementView.selectedEntry?.path === "computer:///","Manage uses shared fuzzy search")
                root.testConfig.pickerFuzzySearch = false
                root.check(panel.managementView.filteredEntries.length === 0,"substring Manage rejects skipped letters")
                root.find("directoryManageSearch").text = "computer"
                root.check(panel.managementView.filteredEntries.length === 1 && panel.managementView.selectedEntry?.path === "computer:///","substring Manage matches consecutive letters")
                root.testConfig.pickerFuzzySearch = true
                root.find("directoryManageSearch").clear()
                root.find("directoryTabs").itemAt(0).clicked()
                root.step = 6
            } else if (root.step === 6) {
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches picker search")
                root.check(!DirectoryService.managing && !panel.adding,"picker Ctrl+A does not add")
                root.check(events.keyClick(Qt.Key_W,Qt.ControlModifier,0),"Ctrl+W reaches picker")
                root.check(DirectoryService.showAll && PickerService.items.length === 2,"show all includes work directories")
                PickerService.directories()
                root.check(!DirectoryService.showAll && !DirectoryService.managing && PickerService.items.length === 1,"reopening resets view and filter")
                panel.management(true)
                panel.managementView.select("computer:///")
                root.find("editDirectory_computer:///").clicked()
                root.find("directoryCategory").selected(root.find("directoryCategory").selectedName === "work" ? "personal" : "work")
                root.find("directoryName").text = "Tomato"
                root.find("cancelDirectory").clicked()
                root.check(DirectoryService.directories.find(entry => entry.path === "computer:///").category === "work","Cancel discards category changes")
                panel.managementView.select("computer:///")
                root.find("editDirectory_computer:///").clicked()
                root.find("directoryCategory").selected(root.find("directoryCategory").selectedName === "work" ? "personal" : "work")
                root.find("directoryName").text = "Tomato"
                root.find("directoryPath").text = "trash:///"
                root.save(7)
            } else if (root.step === 7) {
                root.check(DirectoryService.directories.length === 2 && PickerService.items.length === 2,"editing atomically replaces path and category")
                root.check(!DirectoryService.directories.some(entry => entry.path === "computer:///"),"old location removed on rename")
                root.check(panel.managementView.selectedEntry?.path === "trash:///","renaming keeps the saved directory selected")
                panel.beginAdd()
                root.find("directoryPath").text = root.folder
                root.save(8, false)
            } else if (root.step === 8) {
                root.check(!!DirectoryService.error && DirectoryService.directories.length === 2,"duplicate folder rejected without overwriting")
                root.find("cancelDirectory").clicked()
                panel.beginAdd()
                root.find("directoryPath").text = root.directory + "/missing"
                root.save(9, false)
            } else if (root.step === 9) {
                root.check(!!DirectoryService.error && DirectoryService.directories.length === 2,"missing folder rejected without saving")
                root.find("cancelDirectory").clicked()
                panel.beginAdd()
                panel.folderPicker.options = Dialogs.FolderDialog.ReadOnly | Dialogs.FolderDialog.DontUseNativeDialog
                panel.folderPicker.currentFolder = "file://" + root.folder
                root.find("browseDirectory").clicked()
                root.check(panel.nativeDialogOpen,"shared browse button opens folder picker")
                panel.folderPicker.selectedFolder = "file://" + root.folder
                panel.folderPicker.accept()
                root.check(!panel.nativeDialogOpen && root.find("directoryPath").text === root.folder,"folder selection fills input without saving")
                root.find("cancelDirectory").clicked()
                panel.beginAdd()
                root.find("directoryPath").text = "network:///"
                root.save(10)
            } else {
                root.check(DirectoryService.directories.length === 3,"additional virtual location can be added")
                if (root.failed) { stop(); Qt.quit(); return }
                panel.managementView.select("network:///")
                root.find("removeDirectory_network:///").clicked()
                root.check(DirectoryService.directories.length === 2,"remove deletes only picker entry")
                PickerService.close()
                if (!root.failed) console.log("PASS: directories setup")
                stop(); Qt.quit()
            }
        }
    }
}
