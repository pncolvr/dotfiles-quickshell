import QtQuick
import "../../../theme"
import "../../../ui" as UI
import "../../../services"

UI.TooltipArea {
    moduleName: "batteries"
    id: root
    normalIconColor: BatteryService.lowestLevelStatus === "normal" ? Theme.text
        : Theme.batteryLevelColors[BatteryService.lowestLevelStatus]
    required property var window
    readonly property bool batteryModule: true
    tooltipSource: root
    tooltipScreen: window.screen
    tooltip: Component { BatteriesTooltip {} }

    UI.BarIcon {
        objectName: "batteryBarIcon"
        text: Theme.batteryIcon
        color: root.moduleIconColor
    }
}
