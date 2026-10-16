pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/launcher"

Scope {
    id: root
    Test.TestCase { id: events; when: false }
    PickerWindow { id: popup }
    FileView {
        id: control
        path: Quickshell.env("WALL_TEST_DIR") + "/control"
        preload: false; blockWrites: true; printErrors: false
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function step(key) {
        const deadline = Date.now() + 1500
        while (!(PickerService.visible && PickerService.selectionKey === "wallpaper." + key
            && PickerService.items.length > 0 && popup.windowActive) && Date.now() < deadline) events.wait(10)
        check(PickerService.visible && PickerService.selectionKey === "wallpaper." + key
            && PickerService.items.length > 0 && popup.windowActive, "native " + key + " remains open and focused; actual="
                + PickerService.selectionKey + " visible=" + PickerService.visible + " rows=" + PickerService.items.length)
        const field = events.findChild(popup.panel, "pickerSearch")
        check(field?.activeFocus, "native " + key + " search focused")
        return field
    }
    function activate(mouse) {
        if (mouse) {
            const deadline = Date.now() + 1000
            while (popup.transitioning && Date.now() < deadline) events.wait(10)
            events.wait(50)
            const list = events.findChild(popup.panel, "pickerList")
            events.mouseClick(list.currentItem, 20, 15, Qt.LeftButton, Qt.NoModifier, 0)
        } else events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
    }
    function run() {
        control.setText('{"monitorSlow":true}')
        for (let iteration = 0; iteration < 4; iteration++) {
            console.log("WALLPAPER NATIVE STAGE", iteration, "image")
            WallpaperService.open()
            const field = step("image")
            field.text = "."
            PickerService.select(PickerService.filteredItems.findIndex(row => row.title.startsWith("quote")), false)
            const selected = PickerService.currentItem.result
            activate(iteration % 2 === 1)
            console.log("WALLPAPER NATIVE STAGE", iteration, "mode")
            step("mode")
            PickerService.select(1, false)
            activate(iteration % 2 === 1)
            console.log("WALLPAPER NATIVE STAGE", iteration, "monitor")
            step("monitor")
            events.wait(100)
            check(PickerService.visible && PickerService.selectionKey === "wallpaper.monitor", "monitor survives delayed focus events")
            events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
            step("image")
            check(PickerService.currentItem?.result === selected && PickerService.query === ".", "selected row and query survive target cancellation")
            events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
            events.tryCompare(popup, "visible", false, 700)
        }
        console.log("PASS: native Wallpaper image → mode → monitor and selected-row return survive Enter/click and delayed reads")
    }
    Timer {
        interval: 30; running: true; repeat: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            try { root.run() } catch(error) { console.error("WALLPAPER NATIVE FAIL:", error) }
            PickerService.close()
            Qt.quit()
        }
    }
}
