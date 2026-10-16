import QtQuick
import "../../theme/ui" as UI
import "../../theme"
import "../../services"

UI.TooltipArea {
    id: root
    moduleName: "updates"
    normalIconColor: UpdatesService.hasPriority ? Theme.warning : UpdatesService.hasUpdates ? Theme.text : Theme.empty
    cursorShape: Qt.PointingHandCursor
    tooltip: Component { UpdatesTooltip {} }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    Row {
        spacing: 4

        UI.BarIcon {
            text: Theme.updatesIcon
            color: root.moduleIconColor
        }

        UI.ColumnText {
            visible: UpdatesService.hasPriority
            text: `${UpdatesService.priorityUpdates.length}`
            color: Theme.warning
        }
    }
}