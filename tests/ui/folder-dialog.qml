pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs as Dialogs
import QtTest as Test
import Quickshell
import "../../src/ui" as UI
import "../../src/bar"
import "../../src/services"

Scope {
    id: root
    property bool failed: false
    property bool deliveredWhileHeld: false
    property int deliveries: 0
    function check(ok,message) { if (!ok) { failed = true; console.error("FOLDER DIALOG FAIL:",message) } }
    QtObject { id: origin }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        id: testWindow
        visible: true
        implicitWidth: 500
        implicitHeight: 260
        UI.FolderPathField { id: field; width: 450; text: "existing draft" }
    }
    TooltipFocusHandler {
        tooltipWindow: testWindow
        ready: TooltipService.visible
        panel: field
        windowActive: false
        dismissOnOutside: false
    }
    Connections {
        target: field.folderPicker
        function onFolderSelected(path) {
            root.deliveredWhileHeld = field.nativeDialogOpen && TooltipService.interactionHeld
            root.deliveries++
        }
    }
    Timer {
        interval: 50
        running: true
        onTriggered: {
            TooltipService.show(100,null,origin,false)
            TooltipService.setPanelHovered(true)
            field.folderPicker.options = Dialogs.FolderDialog.ReadOnly | Dialogs.FolderDialog.DontUseNativeDialog
            field.folderPicker.currentFolder = Quickshell.env("FOLDER_TEST_URL")
            field.folderPicker.open()
            root.check(field.nativeDialogOpen && TooltipService.interactionHeld && !TooltipService.pinned,
                "native session retains its owner without pinning")
            field.folderPicker.selectedFolder = Quickshell.env("FOLDER_TEST_URL")
            field.folderPicker.accept()
            root.check(root.deliveries === 1 && root.deliveredWhileHeld,
                "accept delivers its path before releasing the owner")
            root.check(field.text === Quickshell.env("FOLDER_TEST_PATH") && !field.nativeDialogOpen,
                "selected directory with spaces, percent and unicode reaches the form")
            root.check(!TooltipService.pinned && !TooltipService.interactionHeld,
                "accept releases only the temporary hold")
            field.folderPicker.open()
            root.check(field.nativeDialogOpen && TooltipService.interactionHeld,"reopening acquires a fresh hold")
            field.folderPicker.reject()
            root.check(root.deliveries === 1 && field.text === Quickshell.env("FOLDER_TEST_PATH") && !field.nativeDialogOpen,
                "cancel preserves the draft and delivers no path")
            root.check(!TooltipService.pinned && !TooltipService.interactionHeld,"cancel releases the hold without pinning")
            TooltipService.dismiss()
            console.log(root.failed ? "FOLDER DIALOG FAIL: native wrapper" : "PASS: folder result is delivered before owner release; encoded paths, cancellation and manual pin state are preserved")
            Qt.quit()
        }
    }
}
