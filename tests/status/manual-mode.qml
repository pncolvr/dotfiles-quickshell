pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/status"
import "../../src/i18n"

WorkerScope {
    id: root
    QtObject {
        id: session
        property bool ready: true
        property bool active: true
        property bool locked: false
        property bool sleeping: false
        property bool canTrack: true
    }
    Component.onCompleted: StatusService.sessionState = session
    FloatingWindow {
        visible: true
        implicitWidth: 900
        implicitHeight: 900
        Loader {
            id: panel
            active: Translations.calendarMonthNames.length === 12
            sourceComponent: StatusTooltip { width: 650 }
        }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    IpcHandler {
        target: "manualModeTest"
        function state(): string {
            if (!panel.item) return JSON.stringify({ready: false})
            return JSON.stringify({ready: StatusService.ready && StatusService.initialized,
                mode: StatusService.status, source: StatusService.source,
                automatic: StatusService.automaticMode, tracking: StatusService.tracking,
                detecting: StatusService.detectionLoading, inFlight: StatusService.detectionInFlight,
                pending: StatusService.detectionPending, error: StatusService.detectionError,
                matches: StatusService.detectionMatches,
                workSelected: root.find(panel.item, "setStatusMode-work").selected,
                personalSelected: root.find(panel.item, "setStatusMode-personal").selected,
                workHint: root.find(panel.item, "setStatusMode-work").hint})
        }
        function click(mode: string): void { root.find(panel.item, "setStatusMode-" + mode).clicked() }
        function refresh(): void {
            StatusService.reload()
            StatusService.refreshDetection()
            StatusService.beginPanel()
            StatusService.endPanel()
            StatusService.saveRules(StatusService.rules)
        }
    }
}
