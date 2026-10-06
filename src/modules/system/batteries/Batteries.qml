import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

UI.TooltipArea {
    id: root
    required property var window
    readonly property bool batteryModule: true
    tooltipSource: root
    tooltipScreen: window.screen
    tooltip: Component { BatteriesTooltip {} }

    UI.IconText {
        objectName: "batteryBarIcon"
        text: Theme.batteryIcon
        color: BatteryService.lowestLevelStatus === "normal" ? Theme.text
            : Theme.batteryLevelColors[BatteryService.lowestLevelStatus]
    }
}
