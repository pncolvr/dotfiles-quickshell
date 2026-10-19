import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/modules/updates" as Updates
import "../../src/services"

Scope {
    id: root
    readonly property string generation: Date.now() + '-' + Math.random()
    readonly property int count: UpdatesService.count
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    FloatingWindow {
        visible: true
        implicitWidth: 380
        implicitHeight: 300
        Updates.UpdatesTooltip { id: panel }
    }
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed() { Quickshell.inhibitReloadPopup() }
    }
    IpcHandler {
        target: "updatesReloadTest"
        function state(): string {
            return JSON.stringify({generation:root.generation, count:root.count,
                search:!!root.find(panel, "updatesSearch"),
                priorityCount:root.find(panel, "updatesPrioritySectionCount")?.text ?? ""})
        }
        function reload(): void { Qt.callLater(() => Quickshell.reload(true)) }
        function quit(): void { Qt.quit() }
    }
}
