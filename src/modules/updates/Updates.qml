import QtQuick
import "../../ui" as UI
import "../../theme"
import "../../services"
import "../../config"

UI.TooltipArea {
    id: root
    moduleName: "updates"
    visible: Config.updatesEnabled
    enabled: visible
    onVisibleChanged: if (!visible && TooltipService.source === root) TooltipService.dismiss()
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
    }
}
