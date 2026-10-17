pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/launcher"

Scope {
    id: root
    PickerWindow { id: popup }
    FileView {
        id: control
        path: Quickshell.env("WALL_TEST_DIR") + "/control"
        preload: false; blockWrites: true; printErrors: false
    }
    function focusState() {
        const handler = driver.find(popup.contentItem,"windowFocusHandler")
        return JSON.stringify({visible:popup.visible, requested:popup.requestedVisible, active:popup.windowActive,
            keyboardMode:handler?.keyboardFocusMode, field:popup.contentItem.Window.window?.activeFocusItem?.objectName,
            ready:handler?.ready, requesting:handler?.requestingKeyboardFocus,
            settled:handler?.activationSettled, retaining:handler?.retainingNativeFocus})
    }
    function ready(key) {
        return PickerService.visible && PickerService.selectionKey === "wallpaper." + key
            && PickerService.items.length > 0 && popup.windowActive
            && driver.find(popup.panel,"pickerSearch")?.activeFocus
    }
    function canActivate(mouse) {
        return !mouse || (!popup.transitioning && !!driver.find(popup.panel,"pickerList")?.currentItem)
    }
    function activate(mouse) {
        if (mouse) driver.click(driver.find(popup.panel,"pickerList").currentItem)
        else driver.key(Qt.Key_Return)
    }
    function scenario(iteration) {
        const mouse = iteration % 2 === 1
        const state = {selected:"", monitorReady:0}
        const name = "iteration " + iteration
        return [
            {name:name + " open",run:() => WallpaperService.open()},
            {name:name + " image",ready:() => ready("image"),run:() => {
                driver.find(popup.panel,"pickerSearch").text = "."
                PickerService.select(PickerService.filteredItems.findIndex(row => row.title.startsWith("quote")),false)
                state.selected = PickerService.currentItem.result
            }},
            {name:name + " choose image",ready:() => canActivate(mouse),run:() => activate(mouse)},
            {name:name + " mode",ready:() => ready("mode"),run:() => PickerService.select(1,false)},
            {name:name + " choose mode",ready:() => canActivate(mouse),run:() => activate(mouse)},
            {name:name + " monitor",ready:() => ready("monitor"),run:() => { state.monitorReady = Date.now() }},
            {name:name + " delayed monitor focus",ready:() => Date.now() - state.monitorReady >= 100,run:() => {
                driver.check(ready("monitor"),"monitor survives delayed focus events")
                driver.key(Qt.Key_Escape)
                driver.check(PickerService.visible,"returning to images must not close the native picker")
            }},
            {name:name + " return to image",ready:() => ready("image"),run:() => {
                driver.check(PickerService.currentItem?.result === state.selected && PickerService.query === ".",
                    "selected row and query survive target cancellation")
                driver.key(Qt.Key_Escape)
            }},
            {name:name + " native close",ready:() => !popup.visible}
        ]
    }
    NativeFocusDriver {
        id: driver
        onFailed: message => { console.error("WALLPAPER NATIVE FAIL:",message,root.focusState()); PickerService.close(); Qt.quit() }
        onCompleted: { console.log("PASS: native Wallpaper image → mode → monitor and selected-row return survive Enter/click and delayed reads"); PickerService.close(); Qt.quit() }
    }
    Component.onCompleted: {
        let steps = [{name:"seed",ready:() => DbService.ready,run:() => control.setText('{"monitorSlow":true}')}]
        for (let iteration = 0; iteration < 4; iteration++) steps = steps.concat(scenario(iteration))
        driver.steps = steps
        driver.running = true
    }
}
