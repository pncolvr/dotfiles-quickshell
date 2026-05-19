import QtQuick

import "../../theme"
import "../../theme/ui" as UI
import "../../services"

UI.TooltipArea {
    id: root
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    tooltip: Component {
        UI.Text {
            text: `${StatusService.status} mode ${StatusService.source === "automatic" ? "detected" : "manually set"}`
        }
    }
    function statusToIcon(status) {
        switch (status) {
            case "personal": return Theme.statusPersonalIcon
            case "work": return Theme.statusWorkingIcon
            default: return Theme.statusUnknownIcon
        }
    }

    UI.IconText {
        color: StatusService.source == "manual" ? Theme.warning : Theme.text
        text: root.statusToIcon(StatusService.status)
    }

    onClicked: (mouse) => {
        switch (mouse.button) {
        case Qt.LeftButton:
            StatusService.toggle()
            break
        case Qt.RightButton:
             StatusService.clear()
            break
        }
    }
}