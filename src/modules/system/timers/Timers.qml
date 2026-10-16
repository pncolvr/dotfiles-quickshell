import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

UI.TooltipArea {
    moduleName: "timers"
    id: root
    required property var window

    readonly property var barEntry: TimersService.barEntry
    readonly property bool roundUp: TimersService.activeCountdowns.length > 0
    tooltipSource: root
    tooltipScreen: window.screen
    tooltip: Component { TimersTooltip {} }



    Row {
        spacing: Theme.moduleSpacing
        UI.BarIcon {
            text: Theme.timersIcon
            color: root.moduleIconColor
        }
        UI.Text {
            objectName: "timersBarText"
            visible: !!root.barEntry
            text: root.barEntry ? TimersService.formatTime(root.barEntry.valueMs, root.roundUp) : ""
            color: root.barEntry?.urgency === 2 ? Theme.urgent : root.barEntry?.urgency === 1 ? Theme.warning : Theme.text
        }
    }
}
