import QtQml
import Quickshell
import "../../src/services"
import "../../src/ui" as UI

WorkerScope {
    id: root
    // The runner inserts the actual shell's root destruction handler here.
    // ROOT_DESTRUCTION_HANDLER
    PersistentProperties {
        id: state
        reloadableId: "tooltip-reload-warnings"
        property int generations: 0
    }
    QtObject {
        id: source
        property bool ownsTooltipWindow: true
    }
    Component { id: content; QtObject {} }
    Component.onCompleted: {
        // Exercise both singleton clipboard workers and the lazy crop worker.
        PickerService.clipboardFuzzy = true; PickerService.clipboardFuzzy = false
        ClipboardPickerService.clipboardFuzzy = true; ClipboardPickerService.clipboardFuzzy = false
        UI.ImageCropCache.pending.fixture = root
        UI.ImageCropCache.active = {serial: 1, key: "fixture", owner: root}
        UI.ImageCropCache.submit("fixture", root, Array(16 * 16).fill(0xffc0c0c0), 16, 16, Date.now())
        TooltipService.openForKeyboard(0, content, source, false, null)
        if (!TooltipService.visible || !TooltipService.ownsTooltipWindow || TooltipService.content !== content) {
            console.error("RELOAD WARNINGS FAIL: active tooltip ownership")
            Qt.quit()
        }
    }
    Timer {
        interval: 80
        running: UI.ImageCropCache.computations > 0
        onTriggered: {
            if (++state.generations < 20) Quickshell.reload(false)
            else {
                console.log("PASS: twenty tooltip generations release their owners and background workers without undefined bindings")
                Qt.quit()
            }
        }
    }
}
