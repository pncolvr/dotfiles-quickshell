import QtQuick
import "../../theme"
import "../../theme/ui"
import "../../services"

StatusBadge {
    visible: WindowService.activeWindowHidden
    badgeColor: Theme.warning
    text: "hidden"
}