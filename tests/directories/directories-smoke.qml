pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs as Dialogs
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"

Scope {
    id: root
    readonly property string directory: Quickshell.env("DIRECTORY_TEST_DIR")
    readonly property string folder: directory + "/home/banana folder"
    property int step: 0
    property int ticks: 0
    property bool failed: false
    Test.TestEvent { id: events }
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
    Timer {
        interval: 80
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 200 || root.failed) { console.error("DIRECTORY FAIL: timeout at " + root.step + ": " + DirectoryService.error); stop(); Qt.quit(); return }
            if (!DbService.ready || DirectoryService.busy || StatusService.status !== "personal") return
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
                root.check(DirectoryService.managing && root.find("directoryForm").visible,"empty Manage shows add form")
                root.find("directoryPath").text = "~/banana folder"
                root.find("directoryName").text = "Banana"
                root.find("saveDirectory").clicked()
                root.step = 2
            } else if (root.step === 2) {
                root.check(DirectoryService.directories.length === 1 && DirectoryService.directories[0].path === root.folder,"local folder saved canonically")
                root.check(!root.find("directoryForm").visible && root.find("beginAddDirectory").visible,"saved folder collapses footer")
                panel.focusSearch()
                root.step = 3
            } else if (root.step === 3) {
                root.check(root.find("directoryManageSearch").activeFocus,"Manage search focused")
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches Manage")
                root.check(root.find("directoryForm").visible,"Ctrl+A opens Add only in Manage")
                root.find("directoryPath").text = "computer:///"
                root.find("directoryCategory").clicked()
                root.step = 4
            } else if (root.step === 4) {
                root.check(root.find("directoryPath").activeFocus,"Add focuses path")
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches open path")
                root.check(root.find("directoryPath").selectedText === "computer:///","Ctrl+A selects path text while adding")
                root.find("saveDirectory").clicked()
                root.step = 5
            } else if (root.step === 5) {
                root.check(DirectoryService.directories.length === 2 && !DirectoryService.draft,"system URI saved without filesystem validation")
                root.check(PickerService.items.length === 1,"work directories hidden outside work")
                root.find("directoryManageSearch").text = "cmptr"
                root.check(root.find("managedDirectory_computer:///") && !root.find("managedDirectory_" + root.folder),"Manage uses shared fuzzy search")
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
                root.find("editDirectory_computer:///").clicked()
                root.find("directoryCategory").clicked()
                root.find("directoryName").text = "Tomato"
                root.find("cancelDirectory").clicked()
                root.check(DirectoryService.directories.find(entry => entry.path === "computer:///").category === "work","Cancel discards category changes")
                root.find("editDirectory_computer:///").clicked()
                root.find("directoryCategory").clicked()
                root.find("directoryName").text = "Tomato"
                root.find("directoryPath").text = "trash:///"
                root.find("saveDirectory").clicked()
                root.step = 7
            } else if (root.step === 7) {
                root.check(DirectoryService.directories.length === 2 && PickerService.items.length === 2,"editing atomically replaces path and category")
                root.check(!DirectoryService.directories.some(entry => entry.path === "computer:///"),"old location removed on rename")
                panel.beginAdd()
                root.find("directoryPath").text = root.folder
                root.find("saveDirectory").clicked()
                root.step = 8
            } else if (root.step === 8) {
                root.check(!!DirectoryService.error && DirectoryService.directories.length === 2,"duplicate folder rejected without overwriting")
                root.find("cancelDirectory").clicked()
                panel.beginAdd()
                root.find("directoryPath").text = root.directory + "/missing"
                root.find("saveDirectory").clicked()
                root.step = 9
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
                root.find("saveDirectory").clicked()
                root.step = 10
            } else {
                root.check(DirectoryService.directories.length === 3,"additional virtual location can be added")
                root.find("removeDirectory_network:///").clicked()
                root.check(DirectoryService.directories.length === 2,"remove deletes only picker entry")
                PickerService.close()
                if (!root.failed) console.log("PASS: directories setup")
                stop(); Qt.quit()
            }
        }
    }
}
