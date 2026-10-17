pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs as Dialogs
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/bar"
import "../../src/modules/system/files"
import "../../src/services"
import "../../src/ui" as UI

Scope {
    id: root
    readonly property string folder: Quickshell.env("RECENT_NATIVE_FOLDER")
    property int step: 0
    property int ticks: 0
    property int loadingTicks: 0
    property bool failed: false
    property var panel: null
    function check(ok, message) { if (!ok) { failed = true; console.error("RECENT NATIVE FAIL:", message) } }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const found = find(child, name); if (found) return found }
        return null
    }
    Test.TestEvent { id: events }
    QtObject { id: origin }
    Component { id: filesContent; RecentFilesTooltip {} }
    TooltipWindow { id: popup }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (++root.ticks > 80 || root.failed) {
                console.error("RECENT NATIVE FAIL: timeout at step", root.step)
                Qt.quit(); return
            }
            switch (root.step) {
            case 0:
                if (!DbService.ready) return
                TooltipService.show(500, filesContent, origin, false, Quickshell.screens[0])
                root.step++; break
            case 1:
                root.panel = popup.loadedContent
                if (!root.panel || RecentFilesService.loading) return
                TooltipService.setPanelHovered(false)
                root.panel.folderPicker.options = Dialogs.FolderDialog.ReadOnly
                root.panel.folderPicker.currentFolder = "file://" + root.folder
                root.panel.openFolderPicker()
                root.step++; break
            case 2:
                if (!root.panel.folderPicker.visible) return
                root.check(TooltipService.visible && TooltipService.interactionHeld && !TooltipService.pinned,
                    "native picker retains the unpinned panel")
                root.panel.folderPicker.selectedFolder = "file://" + root.folder
                root.panel.folderPicker.accept()
                root.step++; break
            case 3:
                root.check(TooltipService.visible && !TooltipService.pinned,
                    "panel remains open through the slow scan without pinning")
                if (RecentFilesService.addingFolder) {
                    root.loadingTicks++
                    root.check(TooltipService.interactionHeld, "pending add holds the owner beyond its hover timeout")
                    return
                }
                if (!popup.nativeWindow.active || popup.requestingKeyboardFocus) return
                const input = root.find(root.panel, "folderAliasInput") as QC.TextField
                const tabs = root.find(root.panel, "recentFilesTabs") as UI.TabBar
                root.check(root.loadingTicks >= 3 && RecentFilesService.activeFolder === root.folder
                    && tabs.count === 2 && tabs.currentIndex === 1, "completed add selects its new tab")
                root.check(root.panel.renameFolder === root.folder && input.activeFocus
                    && input.text === "chosen directory" && input.selectedText === input.text,
                    "native focus returns to Edit with the entire directory name selected")
                root.check(events.keyClick(Qt.Key_X, Qt.NoModifier, 0), "native typing reaches the editor")
                root.check(input.text === "x", "typing replaces the selected name")
                root.check(events.keyClick(Qt.Key_Return, Qt.NoModifier, 0), "Enter reaches the editor")
                root.check(RecentFilesService.folderLabel(root.folder) === "x" && root.panel.renameFolder === "",
                    "Enter saves through the existing Edit action")
                TooltipService.dismiss()
                console.log(root.failed ? "RECENT NATIVE FAIL: folder handoff" : "PASS: native Recent Files add survives slow scan, selects its tab and focuses Edit with the name fully selected")
                Qt.quit(); break
            }
        }
    }
}
