import QtQuick
import Quickshell
import "../../modules/system/batteries"
import "../../services"
import "../../theme"

Scope {
    id: root
    property int ticks: 0
    property bool sawReloadScan: false
    PersistentProperties {
        id: testState
        reloadableId: "battery-reload-smoke"
        property bool reloaded: false
    }
    FloatingWindow {
        id: window
        visible: false
        Batteries { id: icon; window: window }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    function fail(message) { console.error("BATTERIES RELOAD FAIL: " + message); Qt.quit() }
    Timer {
        id: ticker
        interval: 25
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 200) { root.fail("timed out"); return }
            if (testState.reloaded) {
                if (TooltipService.visible) root.fail("background scan opened the tooltip")
                else if (!BatteryService.batteries.some(battery => battery.id === "solaar:reload-trackball" && battery.percentage === 20))
                    root.fail("receiver reading lost across configuration reload")
                else if (root.find(icon, "batteryBarIcon").color.toString() !== Theme.warning.toString())
                    root.fail("warning color lost across configuration reload")
                else if (BatteryService.scanningReceivers) root.sawReloadScan = true
                else if (!root.sawReloadScan) root.fail("background polling did not restart after reload")
                else { console.log("PASS: configuration reload retains receiver readings and warning color during background rescanning without hover"); Qt.quit() }
                return
            }
            if (BatteryService.scanningReceivers) return
            if (BatteryService.lowestLevelStatus !== "low") { root.fail("initial warning reading"); return }
            if (TooltipService.visible) { root.fail("startup scan required hovering"); return }
            testState.reloaded = true
            ticker.stop()
            Quickshell.reload(false)
        }
    }
}
