import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui"
import "../../services"

StatusBadge {
    visible: WindowService.activeWindowHidden
    badgeColor: Theme.warning
    text: Translations.text("common.states.hidden")
}