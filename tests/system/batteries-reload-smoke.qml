import QtQuick
import Quickshell
import "../../modules/system/batteries"
import "../../services"
import "../../theme"

Scope {
    id: root
    property int step: 0
    property int ticks: 0
    PersistentProperties {
        id: testState
        reloadableId: "battery-reload-smoke"
        property bool reloaded: false
    }
    QtObject { id: origin; readonly property bool batteryModule: true }
    Component { id: content; Item {} }
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
                if (BatteryService.active || BatteryService.scanningReceivers) root.fail("scan started before hover")
                else if (!BatteryService.batteries.some(battery => battery.id === "solaar:reload-trackball" && battery.percentage === 20))
                    root.fail("receiver reading lost across configuration reload")
                else if (root.find(icon, "batteryBarIcon").color.toString() !== Theme.warning.toString())
                    root.fail("warning color lost across configuration reload")
                else { console.log("PASS: configuration reload retains receiver readings and warning color without rescanning before hover"); Qt.quit() }
                return
            }
            switch (root.step) {
            case 0:
                TooltipService.show(200, content, origin, false)
                root.step++
                break
            case 1:
                if (BatteryService.scanningReceivers) return
                if (BatteryService.lowestLevelStatus !== "low") { root.fail("initial warning reading"); return }
                TooltipService.hide()
                root.step++
                break
            case 2:
                if (BatteryService.active) return
                testState.reloaded = true
                ticker.stop()
                Quickshell.reload(false)
                break
            }
        }
    }
}
