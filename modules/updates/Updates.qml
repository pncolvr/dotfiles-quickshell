import QtQuick
import "../../theme/ui" as UI
import "../../theme"
import "../../services"

UI.TooltipArea {
    tooltip: Component { UpdatesTooltip {} }
    onClicked: UpdatesService.install()
    Row {
        spacing: 4

        UI.IconText {
            text: Theme.updatesIcon
            color: UpdatesService.hasPriority ? Theme.warning : UpdatesService.hasUpdates ? Theme.text : Theme.empty
        }

        UI.ColumnText {
            visible: UpdatesService.hasPriority
            text: `${UpdatesService.priorityUpdates.length}`
            color: Theme.warning
        }
    }
}