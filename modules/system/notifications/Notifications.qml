import QtQuick

import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

UI.TooltipArea {
    id: root
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    tooltip: Component {
        UI.Text {
            text: NotificationService.dndEnabled ? "dnd enabled" : "dnd disabled"
        }
    }

    UI.IconText {
        text: NotificationService.dndEnabled
            ? Theme.notificationsDndEnabledIcon
            : Theme.notificationsDndDisabledIcon
    }

    onClicked: (mouse) => {
        switch (mouse.button) {
        case Qt.LeftButton:
            NotificationService.toggle()
            break
        case Qt.RightButton:
            NotificationService.openPanel()
            break
        }
    }
}