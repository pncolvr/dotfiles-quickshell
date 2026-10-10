import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

UI.TooltipArea {
    moduleName: "timers"
    id: root
    required property var window
    readonly property bool tooltipKeyboardFocus: true
    readonly property var barEntry: TimersService.barEntry
    readonly property bool roundUp: TimersService.activeCountdowns.length > 0
    tooltipSource: root
    tooltipScreen: window.screen
    tooltip: Component { TimersTooltip {} }

    onClicked: {
        const pos = root.mapToGlobal(root.width / 2, 0)
        TooltipService.togglePin(pos.x, tooltip, root, centerTooltip, tooltipScreen)
    }

    Row {
        spacing: Theme.moduleSpacing
        UI.IconText {
            text: Theme.timersIcon
            color: TooltipService.pinned && TooltipService.source === root ? Theme.accent : Theme.text
        }
        UI.Text {
            objectName: "timersBarText"
            visible: !!root.barEntry
            text: root.barEntry ? TimersService.formatTime(root.barEntry.valueMs, root.roundUp) : ""
            color: root.barEntry?.urgency === 2 ? Theme.urgent : root.barEntry?.urgency === 1 ? Theme.warning : Theme.text
        }
    }
}
