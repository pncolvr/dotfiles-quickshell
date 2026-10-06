import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

UI.TooltipArea {
    id: root
    required property var window
    readonly property bool notificationsModule: true
    ownsTooltipWindow: true
    tooltipSource: root
    tooltipScreen: window.screen
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    tooltip: Component {
        UI.Text { text: NotificationService.dndEnabled ? "dnd enabled" : "dnd disabled" }
    }
    UI.IconText {
        text: NotificationService.dndEnabled ? Theme.notificationsDndEnabledIcon : Theme.notificationsDndDisabledIcon
        color: TooltipService.pinned && TooltipService.source === root ? Theme.accent : Theme.text
    }
    onClicked: {
        const pos = root.mapToGlobal(root.width / 2, 0)
        TooltipService.togglePin(pos.x, tooltip, root, false, window.screen)
    }
}
