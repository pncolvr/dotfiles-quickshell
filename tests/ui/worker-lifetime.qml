import QtQml
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/ui" as UI

// No shell destruction callback: WorkerScope must release every worker itself.
WorkerScope {
    id: root
    property int generation: 0
    FileView {
        id: counter
        path: Qt.resolvedUrl("worker-generations")
        preload: true
        blockLoading: true
    }
    Component.onCompleted: {
        generation = Number(counter.text()) + 1
        counter.setText(String(generation))
        PickerService.clipboardFuzzy = true; PickerService.clipboardFuzzy = false
        ClipboardPickerService.clipboardFuzzy = true; ClipboardPickerService.clipboardFuzzy = false
        UI.ImageCropCache.pending.fixture = root
        UI.ImageCropCache.active = {serial: 1, key: "fixture", owner: root}
        UI.ImageCropCache.submit("fixture", root, Array(128 * 128).fill(0xffc0c0c0), 128, 128, Date.now())
    }
    Timer {
        interval: 1
        running: UI.ImageCropCache.computations > 0
        onTriggered: {
            if (root.generation < 10) Quickshell.reload(Quickshell.env("WORKER_RELOAD_MODE") === "hard")
            else {
                console.log("PASS: ten worker generations reload and exit without a shell cleanup callback")
                Qt.quit()
            }
        }
    }
}
