import "../../../i18n"
import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

UI.TooltipArea {
    moduleName: "notifications"
    id: root
    required property var window
    readonly property bool notificationsModule: true
    ownsTooltipWindow: true
    tooltipSource: root
    tooltipScreen: window.screen
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    tooltip: Component {
        UI.Text { text: Translations.text(NotificationService.dndEnabled ? "notifications.dnd.enabledStatus" : "notifications.dnd.disabledStatus") }
    }
    UI.BarIcon {
        text: NotificationService.dndEnabled ? Theme.notificationsDndEnabledIcon : Theme.notificationsDndDisabledIcon
        color: root.moduleIconColor
    }

}
