pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs as Dialogs
import QtTest as Test
import Quickshell
import "../../src/modules/launcher"
import "../../src/services"
import "../../src/ui" as UI

WorkerScope {
    id: root
    readonly property string folder: Quickshell.env("PROJECT_TEST_DIR") + "/single folder"
    property int step: 0
    property int ticks: 0
    property bool dispatching: false
    property var projectPanel: null
    property bool failed: false
    Test.TestEvent { id: events }
    PickerWindow { id: popup }
    function trace(stage) {
        if (Quickshell.env("PROJECT_FOCUS_TRACE") !== "1") return
        const handler = root.find(popup.contentItem, "windowFocusHandler")
        console.log("PROJECT FOCUS", stage, JSON.stringify({step, visible: PickerService.visible,
            requested: popup.requestedVisible, active: popup.windowActive,
            focus: popup.contentItem.Window.window?.activeFocusItem?.objectName,
            mode: handler?.keyboardFocusMode, ready: handler?.ready,
            requesting: handler?.requestingKeyboardFocus, settled: handler?.activationSettled,
            retaining: handler?.retainingNativeFocus, generation: handler?.activationGeneration}))
    }
    onStepChanged: trace("step")
    Connections {
        target: popup.contentItem.Window.window
        function onActiveChanged() { root.trace("native activation") }
        function onActiveFocusItemChanged() { root.trace("focus item") }
    }
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
        root.find(popup.contentItem,PickerService.mode === PickerService.Mode.Directories ? "browseDirectory" : "browseProjectSource").clicked()
    }
    Timer {
        interval: 150
        running: !root.dispatching
        repeat: true
        onTriggered: {
            // Synthetic input may process nested events before the step advances.
            if (root.dispatching) return
            root.dispatching = true
            try {
                if (++root.ticks > 60 || root.failed) {
                    root.trace("timeout")
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
                    const hints = root.find(popup.contentItem,"pickerFooterHint") as UI.ShortcutHints
                    root.check(hints.selectedHints
                        === UI.Keybinds.panelHintText("projects", hints.availableActions, hints.actionOverrides),
                        "Projects hints follow the configured selection actions")
                    root.check(!hints.text || hints.lineCount === 1,"Projects hints fit on one line when configured")
                    root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches native Projects search")
                    root.check(!ProjectService.managing && !root.projectPanel.adding,"Ctrl+A does not open Add from Projects")
                    search.clear()
                    root.check(events.keyClick(Qt.Key_W,Qt.ControlModifier,0),"Ctrl+W reaches Projects search")
                    root.check(ProjectService.showAll && PickerService.items.length === 2,"Ctrl+W includes work projects outside work status")
                    root.check(events.keyClick(Qt.Key_W,Qt.ControlModifier,0),"Ctrl+W reaches Projects search again")
                    root.check(!ProjectService.showAll && PickerService.items.length === 1,"Ctrl+W restores the status filter")
                    ProjectService.toggleShowAll()
                    PickerService.close()
                    root.step = 8
                } else if (root.step === 8) {
                    if (popup.visible || popup.windowActive) return
                    PickerService.projects(true)
                    root.check(!ProjectService.showAll && PickerService.items.length === 1,"reopening resets all-projects override for GitHub too")
                    root.step = 9
                } else if (root.step === 9) {
                    const handler = root.find(popup.contentItem, "windowFocusHandler")
                    if (!popup.windowActive || !handler?.activationSettled || !handler.retainingNativeFocus
                        || handler.requestingKeyboardFocus) return
                    root.projectPanel = root.find(popup.contentItem,"projectPickerPanel")
                    const search = root.find(popup.contentItem,"pickerSearch")
                    search.forceActiveFocus()
                    root.trace("before GitHub Ctrl+W")
                    root.check(events.keyClick(Qt.Key_W,Qt.ControlModifier,0),"Ctrl+W reaches GitHub search")
                    root.trace("after GitHub Ctrl+W")
                    const hints = root.find(popup.contentItem,"pickerFooterHint") as UI.ShortcutHints
                    root.check(hints.selectedHints === UI.Keybinds.panelHintText("projects", hints.availableActions, hints.actionOverrides)
                        && hints.selectedHints.includes(UI.Keybinds.sequence("selection.toggle")),
                        "GitHub selection hints follow the configured actions")
                    root.step = 90
                } else if (root.step === 90) {
                    if (!popup.windowActive) return
                    root.check(events.keyClick(Qt.Key_Space,Qt.ShiftModifier,0),"Shift+Space reaches GitHub search")
                    root.check(PickerService.selectedIds.length === 1 && PickerService.currentIndex === 1,"Shift+Space selects GitHub row and advances")
                    root.step = 91
                } else if (root.step === 91) {
                    if (!popup.windowActive) return
                    root.check(events.keyClick(Qt.Key_Space,Qt.ShiftModifier,0),"Shift+Space reaches next GitHub row")
                    const search = root.find(popup.contentItem,"pickerSearch")
                    root.check(PickerService.selectedItems.length === 2 && search.text === "","Shift+Space selects multiple URLs without adding query spaces")
                    root.step = 92
                } else if (root.step === 92) {
                    if (!popup.windowActive) return
                    root.check(events.keyClick(Qt.Key_Space,Qt.NoModifier,0),"plain Space reaches GitHub search")
                    const search = root.find(popup.contentItem,"pickerSearch")
                    root.check(search.text === " ","plain Space keeps normal search typing")
                    search.clear()
                    PickerService.deselectAll()
                    root.find(popup.contentItem,"pickerList").forceActiveFocus()
                    root.step = 93
                } else if (root.step === 93) {
                    if (!popup.windowActive) return
                    root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches GitHub list")
                    root.check(PickerService.selectedIds.length === 2 && !ProjectService.managing,"GitHub Ctrl+A selects visible URLs")
                    root.step = 94
                } else if (root.step === 94) {
                    if (!popup.windowActive) return
                    root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0),"Ctrl+A reaches GitHub search again")
                    root.check(PickerService.selectedIds.length === 0,"GitHub Ctrl+A clears the selection")
                    root.step = 95
                } else if (root.step === 95) {
                    if (!popup.windowActive) return
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
                    const hints = root.find(popup.contentItem,"managementHints") as UI.ShortcutHints
                    root.check(hints.selectedHints === UI.Keybinds.panelHintText("manage", hints.availableActions, hints.actionOverrides)
                        && hints.selectedHints.includes(UI.Keybinds.sequence("add")),"Manage shows configured action hints")
                    const search = root.find(popup.contentItem,"projectManageSearch")
                    search.forceActiveFocus()
                    root.check(search.activeFocus,"Manage search receives native keyboard focus")
                    root.check(events.keyClick(Qt.Key_N,Qt.ControlModifier,0),"Ctrl+N reaches native Manage search")
                    root.check(root.find(popup.contentItem,"projectAddForm").visible,"Ctrl+N opens the add footer from Manage search")
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
                } else if (root.step === 5) {
                    root.check(PickerService.visible && popup.visible,"cancel keeps Manage open")
                    if (!popup.windowActive || popup.restoringDialogFocus) return
                    root.check(root.find(popup.contentItem,"projectSourcePath").text === root.folder,"cancel preserves the previous path")
                    root.check(!ProjectService.busy && ProjectService.sources.length === 2 && ProjectRepository.projects.length === 2,"choosing a folder does not scan or save")
                    PickerService.directories()
                    root.step = 10
                } else if (root.step === 10) {
                    if (!popup.visible || !popup.windowActive) return
                    root.projectPanel = root.find(popup.contentItem,"directoryPickerPanel")
                    root.check(!!root.projectPanel,"native directory panel exists")
                    root.check(root.find(popup.contentItem,"pickerFooterHint").text === "", "directory list has no configured hints")
                    root.check(events.keyClick(Qt.Key_M,Qt.ControlModifier,0),"Ctrl+M opens native directory management")
                    root.check(DirectoryService.managing,"native directory management is open")
                    root.step = 11
                } else if (root.step === 11) {
                    if (!root.projectPanel.adding) {
                        events.keyClick(Qt.Key_N,Qt.ControlModifier,0)
                        return
                    }
                    root.check(root.find(popup.contentItem,"directoryPath").activeFocus,"directory form focuses its path input")
                    root.openDialog()
                    root.step = 12
                } else if (root.step === 12) {
                    if (popup.windowActive) return
                    root.check(PickerService.visible,"native directory dialog keeps picker open")
                    root.projectPanel.folderPicker.selectedFolder = "file://" + root.folder
                    root.projectPanel.folderPicker.accept()
                    root.step = 13
                } else {
                    root.check(PickerService.visible && popup.visible && DirectoryService.managing,"directory dialog accept keeps Manage open")
                    if (!popup.windowActive || popup.restoringDialogFocus) return
                    root.check(root.find(popup.contentItem,"directoryPath").text === root.folder,"directory dialog selection fills shared field")
                    root.check(DirectoryService.directories.length === 0,"choosing directory does not save automatically")
                    PickerService.close()
                    if (!root.failed) console.log("PASS: project folder picker returns focus after accept and cancel; directories share native dialog focus")
                    stop(); Qt.quit()
                }
            } finally {
                root.dispatching = false
            }
        }
    }
}
