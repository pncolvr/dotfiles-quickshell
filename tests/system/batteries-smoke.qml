import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../modules/system/batteries"
import "../../services"
import "../../theme"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    property var fixtures: []
    QtObject { id: origin; readonly property bool batteryModule: true }
    Component { id: content; Item {} }

    function check(condition, message) {
        if (condition) return
        failed = true
        console.error("BATTERIES SMOKE FAIL: " + message)
    }

    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }

    function powerDevice(overrides) {
        return Object.assign({
            ready: true, type: UPowerDeviceType.Battery, isPresent: true,
            nativePath: "BAT0", model: "", isLaptopBattery: true, percentage: 0.5,
            state: UPowerDeviceState.Discharging, iconName: "battery-good-symbolic",
            timeToEmpty: 7200, timeToFull: 0
        }, overrides)
    }

    function bluetoothDevice(overrides) {
        return Object.assign({
            dbusPath: "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF", address: "AA:BB:CC:DD:EE:FF",
            name: "Headphones", deviceName: "Headphones", connected: true,
            batteryAvailable: true, battery: 0.75
        }, overrides)
    }

    // QObject fixtures verify that QML observes changes inside the device arrays.
    QtObject {
        id: laptop
        property bool ready: true
        property int type: UPowerDeviceType.Battery
        property bool isPresent: true
        property string nativePath: "BAT0"
        property string model: ""
        property bool isLaptopBattery: true
        property real percentage: 0.5
        property int state: UPowerDeviceState.Discharging
        property string iconName: "battery-good-symbolic"
        property real timeToEmpty: 7200
        property real timeToFull: 0
    }
    readonly property var observed: BatteryService.collectBatteries([laptop], [], true)

    FloatingWindow {
        id: preview
        visible: true
        color: Theme.background
        implicitWidth: Theme.batteryTooltipWidth + 40
        implicitHeight: 700
        BatteriesTooltip { id: popup; x: 20; y: 20; batteries: root.fixtures }
        Batteries { id: barIcon; window: preview; visible: false }
    }

    Timer {
        id: ticker
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            if (root.step === 1 && BatteryService.scanningReceivers) return
            switch (root.step++) {
            case 0: {
                root.check(!BatteryService.active && !BatteryService.scanningReceivers, "receiver scans do not start before hover")
                const peripheral = root.powerDevice({
                    type: UPowerDeviceType.Keyboard, nativePath: "hidpp_battery_0", model: "PRO X Wireless",
                    isLaptopBattery: false, isPresent: false, percentage: 0.91,
                    state: UPowerDeviceState.Unknown, timeToEmpty: 0
                })
                const charging = root.powerDevice({nativePath: "BAT1", percentage: 0.25, state: UPowerDeviceState.Charging, timeToFull: 4800})
                root.fixtures = BatteryService.collectBatteries([peripheral, laptop, charging], [root.bluetoothDevice()], false)
                root.check(root.fixtures.length === 4, "internal and peripheral batteries included")
                root.check(root.fixtures[0].internal && root.fixtures[1].internal, "laptop batteries sorted first")
                root.check(root.fixtures[3].name === "PRO X Wireless" && root.fixtures[3].percentage === 91, "peripheral without IsPresent and percent scaling")
                root.check(root.fixtures[0].pluggedIn && !root.fixtures[3].pluggedIn, "AC power only applies to laptop batteries")
                root.check(BatteryService.timeText(root.fixtures[0]) === "Empty in 2 h", "discharge estimate")
                root.check(BatteryService.timeText(root.fixtures[1]) === "Full in 1 h 20 min", "charge estimate")

                const bt = root.bluetoothDevice()
                const duplicate = root.powerDevice({nativePath: bt.dbusPath, model: "Headphones", isLaptopBattery: false})
                root.check(BatteryService.collectBatteries([duplicate], [bt], true).length === 1, "Bluetooth duplicate merged")
                root.check(BatteryService.collectBatteries([duplicate], [root.bluetoothDevice({connected: false})], true).length === 0, "disconnected Bluetooth excluded from both sources")
                root.check(BatteryService.collectBatteries([], [root.bluetoothDevice({batteryAvailable: false})], true).length === 0, "Bluetooth device without battery excluded")
                root.check(BatteryService.collectBatteries([
                    root.powerDevice({type: UPowerDeviceType.LinePower}), root.powerDevice({isPresent: false}), root.powerDevice({ready: false})
                ], [], true).length === 0, "AC adapters, absent and uninitialized batteries excluded")
                root.check(BatteryService.collectBatteries([root.powerDevice({type: UPowerDeviceType.Ups, isLaptopBattery: false, isPresent: false})], [], true).length === 1, "UPS included")
                root.check(BatteryService.percentage(0) === 0 && BatteryService.percentage(1) === 100 && BatteryService.percentage(NaN) === null, "empty, full and unknown levels distinguished")
                root.check(BatteryService.percentage(-1) === 0 && BatteryService.percentage(2) === 100, "out-of-range levels clamped")
                root.check(BatteryService.durationText(30) === "less than a minute" && BatteryService.durationText(0) === "", "short and unavailable estimates")
                root.check(BatteryService.timeText({state: "charging", timeToFull: 0}) === "", "missing charge estimate omitted")
                root.check(BatteryService.timeText({state: "discharging", timeToEmpty: 0}) === "", "missing discharge estimate omitted")
                root.check(BatteryService.timeText({state: "unknown"}) === "", "unknown estimate omitted")
                root.check(BatteryService.levelStatus(21) === "normal" && BatteryService.levelStatus(20) === "low"
                    && BatteryService.levelStatus(10) === "critical" && BatteryService.levelStatus(null) === "normal", "shared low and critical thresholds")
                const receivers = [
                    {id: "solaar:mouse", nativePath: "hidpp_battery_0", name: "PRO X Wireless", brand: "Logitech", percentage: 91, state: "discharging", pluggedIn: false, internal: false},
                    {id: "solaar:trackball", nativePath: "", name: "ERGO M575S Trackball", percentage: 20, state: "discharging", pluggedIn: false, internal: false},
                    {id: "solaar:headset", nativePath: "", name: "PRO X 2 LIGHTSPEED", percentage: 95, state: "discharging", pluggedIn: false, internal: false}
                ]
                const merged = BatteryService.mergeReceiverBatteries(BatteryService.collectBatteries([peripheral], [], true), receivers)
                root.check(merged.length === 3 && merged[0].name === "ERGO M575S Trackball", "both mice and headset included without duplicate UPower mouse")
                root.check(merged.find(battery => battery.name === "PRO X Wireless").state === "discharging", "receiver supplies missing native status")
                root.check(BatteryService.displayName(merged.find(battery => battery.name === "PRO X Wireless")) === "Logitech PRO X Wireless", "brand added to native merged model")
                root.check(BatteryService.displayName({name: "Logitech Mouse", brand: "Logitech"}) === "Logitech Mouse", "existing brand is not repeated")
                root.check(BatteryService.mergeReceiverBatteries([], []).length === 0, "receiver disconnect removes fallback devices")
                const incomplete = Object.assign({}, receivers[1], {percentage: null})
                root.check(BatteryService.receiverSnapshot(receivers, [incomplete])[0].percentage === 20,
                    "connected receiver device retains last known percentage when new level is unavailable")
                root.check(BatteryService.receiverSnapshot(receivers, []).length === 0, "confirmed disconnection clears cached device")
                laptop.percentage = 0.8
                laptop.state = UPowerDeviceState.Charging
                laptop.timeToFull = 3600
                TooltipService.show(200, content, origin, false)
                break
            }
            case 1: {
                root.check(root.observed[0].percentage === 80 && root.observed[0].state === "charging" && root.observed[0].timeToFull === 3600, "live device property changes observed")
                const list = root.find(popup, "batteryList")
                list.forceLayout()
                const row = list.itemAtIndex(0)
                const body = root.find(row, "batteryBody")
                const fill = root.find(row, "batteryFill")
                root.check(Math.abs(fill.width / (body.width - 2) - 0.5) < 0.001, "battery fill matches percentage")
                root.check(root.find(row, "batteryName").text.includes("BAT0") && root.find(row, "batteryPercentage").text === "50%", "card name and percentage")
                root.check(root.find(row, "batteryPowerIcon").visible, "plug icon on external power")
                root.check(root.find(row, "batteryTime").text === "Empty in 2 h", "card time label")
                root.check(BatteryService.active && BatteryService.batteries.some(battery => battery.name === "ERGO M575S Trackball"), "hover scans receiver batteries")
                root.check(root.find(barIcon, "batteryBarIcon").text === Theme.batteryIcon
                    && root.find(barIcon, "batteryBarIcon").color.toString() === Theme.warning.toString(), "full battery icon uses lowest device warning color")
                const states = [UPowerDeviceState.Charging, UPowerDeviceState.Discharging, UPowerDeviceState.FullyCharged,
                    UPowerDeviceState.PendingCharge, UPowerDeviceState.PendingDischarge, UPowerDeviceState.Empty, UPowerDeviceState.Unknown]
                root.fixtures = BatteryService.collectBatteries(states.concat(states).map((state, index) => root.powerDevice({
                    nativePath: "BAT" + index, percentage: [0.25, 0.5, 1, 0.8, 0.4, 0, 0.91][index % states.length],
                    state: state, timeToFull: 4800, timeToEmpty: 10800
                })), [], false)
                break
            }
            case 2: {
                const list = root.find(popup, "batteryList")
                list.forceLayout()
                root.check(list.contentHeight > list.height && list.height <= popup.maxListHeight, "many devices scroll within monitor height")
                list.positionViewAtEnd()
                break
            }
            case 3:
                root.fixtures = []
                TooltipService.hide()
                break
            case 4:
                root.check(root.find(popup, "batteryList").height === 0, "empty list collapses")
                if (BatteryService.active) { root.step--; return }
                root.check(!BatteryService.scanningReceivers && BatteryService.lowestLevelStatus === "low", "hover exit stops scans and retains bar color")
                if (!root.failed) console.log("PASS: battery discovery, duplicates, disconnects, percentages, power, estimates, live updates, cards, scrolling and empty state")
                ticker.stop()
                Qt.quit()
                break
            }
        }
    }
}
