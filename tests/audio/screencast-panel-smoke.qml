import QtQuick
import Quickshell
import "../../src/services"
import "../../src/modules/hyprland"

Scope {
    id: root
    property int attempts: 0
    function texts(item) {
        if (!item) return []
        let values = typeof item.text === "string" ? [item.text] : []
        for (const child of item.children ?? []) values = values.concat(texts(child))
        return values
    }
    FloatingWindow {
        visible: true
        implicitWidth: 450
        implicitHeight: 200
        Screencast { id: indicator }
        Loader { id: panel; x: 50; y: 20; sourceComponent: indicator.tooltip }
    }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            const labels = root.texts(panel.item)
            if (indicator.visible && AudioService.screencastStreams.length === 2
                && labels.includes("Screen sharing") && labels.includes("banana") && labels.includes("potato")) {
                console.log("PASS: native capture descriptions and live tooltip")
                Qt.quit()
            } else if (++root.attempts > 100) {
                console.error("SCREENCAST FAIL: panel timeout " + JSON.stringify(labels))
                Qt.quit()
            }
        }
    }
}
