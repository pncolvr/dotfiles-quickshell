import QtQuick
import Quickshell
import "../../modules/system/batteries"
import "../../services"

Scope {
    id: root
    property int step: 0
    property int ticks: 0
    property bool failed: false
    property bool retainDevice: false
    property real expectedPercentage: 20
    property string previousColor: ""
    property int refreshTicks: 0

    QtObject { id: origin; readonly property bool batteryModule: true }
    Component { id: content; Item {} }
    FloatingWindow {
        id: window
        visible: false
        Batteries { id: icon; window: window }
    }

    function reading() {
        return BatteryService.batteries.find(battery => battery.id === "solaar:refresh-trackball")
    }

    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }

    function iconColor() { return find(icon, "batteryBarIcon").color.toString() }

    function check(condition, message) {
        if (condition) return
        root.failed = true
        console.error("BATTERIES REFRESH FAIL: " + message)
    }

    function closeForRefresh() {
        root.previousColor = iconColor()
        TooltipService.hide()
        root.step++
    }

    Connections {
        target: BatteryService
        function onBatteriesChanged() {
            if (root.retainDevice) root.check(!!root.reading(), "cached device disappeared before a successful refresh")
        }
    }

    Timer {
        id: ticker
        interval: 25
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 400 || root.failed) {
                root.check(false, "refresh test failed or timed out at step " + root.step)
                ticker.stop()
                Qt.quit()
                return
            }
            switch (root.step) {
            case 0:
                TooltipService.show(200, content, origin, false)
                root.step++
                break
            case 1:
                if (BatteryService.scanningReceivers) return
                root.check(root.reading()?.percentage === 20, "initial receiver reading")
                root.retainDevice = true
                root.closeForRefresh()
                break
            case 2:
            case 4:
            case 6:
            case 8:
                if (BatteryService.active) return
                TooltipService.show(200, content, origin, false)
                root.refreshTicks = 0
                root.step++
                break
            case 3:
            case 5:
            case 7:
            case 9:
                if (BatteryService.scanningReceivers) {
                    root.refreshTicks++
                    root.check(root.reading()?.percentage === root.expectedPercentage, "previous reading changed during refresh")
                    root.check(root.iconColor() === root.previousColor, "bar color changed during refresh")
                    return
                }
                root.check(root.refreshTicks > 5, "slow scan exercised cached data")
                if (root.step === 3) {
                    root.check(root.reading()?.percentage === 50, "successful refresh replaces cached data")
                    root.expectedPercentage = 50
                } else if (root.step === 5) {
                    root.check(root.reading()?.percentage === 50 && BatteryService.receiverError.length > 0,
                        "failed refresh keeps cached data and reports error")
                } else if (root.step === 7) {
                    root.check(root.reading()?.percentage === 5 && !BatteryService.receiverError,
                        "next successful refresh replaces data and clears error")
                    root.check(BatteryService.lowestLevelStatus === "critical", "fresh critical level updates bar color")
                    root.expectedPercentage = 5
                    root.retainDevice = false
                } else {
                    root.check(!root.reading() && !BatteryService.receiverError,
                        "confirmed empty refresh removes disconnected device")
                    if (!root.failed) console.log("PASS: receiver refresh preserves readings and bar color until new data, retains data on failure, recovers, and removes confirmed disconnections")
                    ticker.stop()
                    Qt.quit()
                    return
                }
                root.closeForRefresh()
                break
            }
        }
    }
}
