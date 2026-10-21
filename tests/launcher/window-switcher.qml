pragma ComponentBehavior: Bound
import QtQuick
import "../../src/ui" as UI
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/theme"

WorkerScope {
    id: root
    property bool failed: false
    property var windows: WindowService
    property var audio: AudioService
    function check(ok, message) { if (!ok) { failed = true; console.error('SWITCHER FAIL:',message) } }
    function clients(count) {
        return Array.from({length:count},(_,index)=>({address:'0x'+(index+1),title:'Window '+(index+1),class:'fixture',
            mapped:true,focusHistoryID:index,workspace:{id:index%2+1,name:String(index%2+1)},size:[800,600]}))
    }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1100
        implicitHeight: 700
        color: Theme.tooltipBackground
        WindowSwitcherPanel {
            id: panel
            width: implicitWidth
            height: implicitHeight
            availableContentWidth: 1100
            availableContentHeight: 650
        }
    }
    Timer {
        interval: 300; running: true
        onTriggered: {
            root.windows.allWindows = root.clients(4)
            PickerService.switchWindows()
            events.wait(30)
            root.check(PickerService.visible && PickerService.currentItem.id === '0x2','opens with previous window selected')
            root.check(root.windows.focused.length === 0,'opening only previews the selection')
            root.check(!panel.previewEnabled && !panel.floatingPreviewRequested && panel.implicitWidth === Theme.pickerWidth,'starts with list only and no capture view')
            panel.focusSearch(); events.keyClick(Qt.Key_I,Qt.ControlModifier | Qt.ShiftModifier)
            events.wait(Theme.clipboardLayoutDuration + 50)
            root.check(panel.previewEnabled && panel.floatingPreviewRequested && panel.implicitWidth === Theme.pickerWidth,'Ctrl+Shift+I requests a floating preview without widening the list')
            events.keyClick(Qt.Key_I,Qt.ControlModifier | Qt.ShiftModifier)
            events.wait(Theme.clipboardLayoutDuration + 50)
            root.check(!panel.previewEnabled && !panel.floatingPreviewRequested,'toggle off releases preview')
            PickerService.switchWindows()
            root.check(PickerService.currentItem.id === '0x3','repeated shortcut advances existing session')
            PickerService.switchWindows(); PickerService.switchWindows()
            root.check(PickerService.currentItem.id === '0x1','forward selection wraps')
            panel.focusSearch()
            events.keyPress(Qt.Key_Backtab,Qt.AltModifier | Qt.ShiftModifier)
            root.check(PickerService.currentItem.id === '0x4','Alt+Shift+Tab moves backwards and wraps')
            PickerService.close()
            events.keyRelease(Qt.Key_Alt)
            events.wait(20)
            root.check(root.windows.focused.length === 0,'cancel plus late release never activates')
            PickerService.switchWindows()
            const selected = PickerService.currentItem.id
            root.windows.allWindows = root.clients(4).reverse()
            root.check(PickerService.currentItem.id === selected && PickerService.items[0].id === '0x1','refresh preserves selection and cycle order')
            root.windows.allWindows = root.clients(4).filter(client=>client.address !== selected)
            root.check(PickerService.currentItem.id !== selected,'closed selection advances to surviving entry')
            panel.focusSearch()
            events.keyRelease(Qt.Key_Alt)
            events.wait(30)
            root.check(PickerService.visible && root.windows.focused.length === 0,'Alt release never activates')
            events.keyClick(Qt.Key_Return)
            events.wait(30)
            root.check(!PickerService.visible && root.windows.focused.length === 1,'Enter confirms once')
            events.keyRelease(Qt.Key_Alt)
            root.check(root.windows.focused.length === 1,'duplicate release is harmless')
            root.windows.allWindows = root.clients(2)
            PickerService.switchWindows()
            root.check(PickerService.visible && root.windows.focused.length === 1,'two windows still show preview before confirmation')
            panel.focusSearch(); events.keyClick(Qt.Key_Escape)
            root.check(!PickerService.visible,'Escape cancels')
            root.windows.allWindows = []
            PickerService.switchWindows(); events.keyRelease(Qt.Key_Alt)
            root.check(PickerService.visible,'fast release leaves switcher open while waiting for rows')
            root.windows.allWindows = root.clients(2)
            events.wait(30)
            root.check(PickerService.visible && root.windows.focused.length === 1,'late snapshot and rapid Alt release never auto-activate')
            panel.focusSearch(); events.keyClick(Qt.Key_Return); events.wait(30)
            root.check(root.windows.focused.slice(-1)[0] === '0x2','Enter accepts late snapshot selection')
            PickerService.switchWindows(); root.windows.allWindows = []
            root.check(!PickerService.visible,'all windows closing cancels switcher')
            root.windows.allWindows = root.clients(2)
            PickerService.windows('all')
            root.check(PickerService.visible,'ordinary two-window picker also waits for explicit acceptance')
            PickerService.switchWindows()
            root.check(!panel.previewEnabled,'reopening resets preview to list only')
            panel.availableContentWidth = 600
            panel.focusSearch(); events.keyClick(Qt.Key_I,Qt.ControlModifier | Qt.ShiftModifier)
            events.wait(Theme.clipboardLayoutDuration + 50)
            root.check(panel.floatingPreviewRequested && panel.implicitWidth === Theme.pickerWidth,'small screen retains the normal list width')
            root.audio.screencastActive = true
            panel.focusSearch(); events.keyClick(Qt.Key_I,Qt.ControlModifier | Qt.ShiftModifier)
            root.check(!UI.MotionPolicy.enabled && !panel.floatingPreviewRequested,'sharing disables preview transition and releases capture immediately')
            events.keyClick(Qt.Key_I,Qt.ControlModifier | Qt.ShiftModifier)
            root.check(panel.floatingPreviewRequested,'preview remains available without decorative motion while sharing')
            PickerService.close()
            if (!root.failed) console.log('PASS: window switcher cycling, reverse keys, explicit acceptance, preview toggle, stable updates and sharing policy')
            Qt.quit()
        }
    }
}
