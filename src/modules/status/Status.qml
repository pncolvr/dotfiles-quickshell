import QtQuick

import "../../theme"
import "../../theme/ui" as UI
import "../../services"

UI.TooltipArea {
    moduleName: "status"
    id: root
    visible: StatusService.enabled
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    normalIconColor: StatusService.source === "manual" ? Theme.warning : Theme.text
    tooltipSource: root

    tooltip: Component { StatusTooltip {} }
    function statusToIcon(status) {
        switch (status) {
            case "personal": return Theme.statusPersonalIcon
            case "work": return Theme.statusWorkingIcon
            default: return Theme.statusUnknownIcon
        }
    }

    UI.BarIcon {
        color: root.moduleIconColor
        text: root.statusToIcon(StatusService.status)
    }


}
