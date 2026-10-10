pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs as Dialogs
import QtTest as Test
import Quickshell
import "../../src/modules/launcher"
import "../../src/services"

Scope {
    id: root
    readonly property string folder: Quickshell.env("PROJECT_TEST_DIR") + "/single folder"
    property int step: 0
    property int ticks: 0
    property var projectPanel: null
    property bool failed: false
    Test.TestEvent { id: events }
    PickerWindow { id: popup }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const match = find(child,name); if (match) return match }
        return null
    }
    function check(condition, message) {
        if (!condition) { failed = true; console.error("PROJECT FAIL: " + message) }
    }
    function openDialog() {
        projectPanel.folderPicker.options = Dialogs.FolderDialog.ReadOnly
        projectPanel.folderPicker.currentFolder = "file://" + root.folder
        root.find(popup.contentItem,"browseProjectSource").clicked()
    }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            if (++root.ticks > 60 || root.failed) {
                console.error("PROJECT FAIL: folder focus timeout at step " + root.step)
                stop(); Qt.quit(); return
            }
            if (!DbService.ready) return
            if (root.step === 0) {
                ProjectRepository.apply([
                    {path:root.folder,kind:"folder",category:"personal",error:"",projects:[
                        {path:root.folder,name:"banana",url:"https://github.com/example/banana",workspaces:[]}]},
                    {path:root.folder + "/potato",kind:"folder",category:"work",error:"",projects:[
                        {path:root.folder + "/potato",name:"potato",url:"https://github.com/example/potato",workspaces:[]}]}
                ],true)
                PickerService.projects()
                root.check(!ProjectService.showAll && PickerService.items.length === 1,"opening uses the status filter")
                root.step = 1
            } else if (root.step === 1) {
                if (!popup.visible || !popup.windowActive) return
                root.projectPanel = root.find(popup.contentItem,"projectPickerPanel")
                root.check(!!root.projectPanel,"project panel exists")
                const search = root.find(popup.contentItem,"pickerSearch")
                search.text = "banana"
                search.forceActiveFocus()
                root.check(search.activeFocus,"Projects search receives native keyboard focus")
                root.check(root.find(popup.contentItem,"pickerFooterHint").text.includes("Ctrl+W")
                    && !root.find(popup.contentItem,"pickerFooterHint").text.includes("Ctrl+A"),"Projects hints show the filter shortcut, without Add")
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches native Projects search")
                root.check(!ProjectService.managing && !root.projectPanel.adding,"Ctrl+A does not open Add from Projects")
                search.clear()
                root.check(events.keyClick(Qt.Key_W,Qt.ControlModifier,0),"Ctrl+W reaches Projects search")
                root.check(ProjectService.showAll && PickerService.items.length === 2,"Ctrl+W includes work projects outside work status")
                root.check(events.keyClick(Qt.Key_W,Qt.ControlModifier,0),"Ctrl+W reaches Projects search again")
                root.check(!ProjectService.showAll && PickerService.items.length === 1,"Ctrl+W restores the status filter")
                ProjectService.toggleShowAll()
                PickerService.projects(true)
                root.check(!ProjectService.showAll && PickerService.items.length === 1,"reopening resets all-projects override for GitHub too")
                root.step = 9
            } else if (root.step === 9) {
                const search = root.find(popup.contentItem,"pickerSearch")
                search.forceActiveFocus()
                root.check(events.keyClick(Qt.Key_W,Qt.ControlModifier,0),"Ctrl+W reaches GitHub search")
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches GitHub search")
                root.check(PickerService.selectedIds.length === 2 && !ProjectService.managing,"GitHub Ctrl+A selects visible URLs")
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches GitHub search again")
                root.check(PickerService.selectedIds.length === 0,"GitHub Ctrl+A clears the selection")
                root.check(events.keyClick(Qt.Key_M,Qt.ControlModifier,0),"Ctrl+M reaches GitHub search")
                root.check(ProjectService.managing,"Ctrl+M opens Manage")
                root.step = 7
            } else if (root.step === 6) {
                const input = root.find(popup.contentItem,"projectSourcePath")
                root.check(input.activeFocus,"add shortcut focuses the path input")
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches the path input")
                root.check(input.selectedText === root.folder,"Ctrl+A selects all path text while adding")
                root.openDialog()
                root.step = 2
            } else if (root.step === 7) {
                root.check(root.find(popup.contentItem,"projectManageHints").text.includes("Ctrl+A")
                    && root.find(popup.contentItem,"projectManageHints").text.includes("Ctrl+M"),"Manage shows shortcut hints")
                const search = root.find(popup.contentItem,"projectManageSearch")
                search.forceActiveFocus()
                root.check(search.activeFocus,"Manage search receives native keyboard focus")
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches native Manage search")
                root.check(root.find(popup.contentItem,"projectAddForm").visible,"Ctrl+A opens the add footer from Manage search")
                root.find(popup.contentItem,"projectSourcePath").text = root.folder
                root.step = 6
            } else if (root.step === 2) {
                if (popup.windowActive) return
                root.check(PickerService.visible,"dialog releases focus without closing launcher")
                root.projectPanel.folderPicker.selectedFolder = "file://" + root.folder
                root.projectPanel.folderPicker.accept()
                root.step = 3
            } else if (root.step === 3) {
                root.check(PickerService.visible && popup.visible && ProjectService.managing,"accept keeps Manage open")
                if (!popup.windowActive || popup.restoringDialogFocus) return
                root.check(root.find(popup.contentItem,"projectSourcePath").text === root.folder,"selected path survives compositor focus return")
                root.openDialog()
                root.step = 4
            } else if (root.step === 4) {
                if (popup.windowActive) return
                root.projectPanel.folderPicker.reject()
                root.step = 5
            } else {
                root.check(PickerService.visible && popup.visible,"cancel keeps Manage open")
                if (!popup.windowActive || popup.restoringDialogFocus) return
                root.check(root.find(popup.contentItem,"projectSourcePath").text === root.folder,"cancel preserves the previous path")
                root.check(!ProjectService.busy && ProjectService.sources.length === 2 && ProjectRepository.projects.length === 2,"choosing a folder does not scan or save")
                PickerService.close()
                if (!root.failed) console.log("PASS: project folder picker returns focus after accept and cancel")
                stop(); Qt.quit()
            }
        }
    }
}
