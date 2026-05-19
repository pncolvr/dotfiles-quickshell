import QtQuick
import "../../theme"
import "../../theme/ui"
import "../../services"

StatusBadge {
    visible: SubmapService.submapActive
    badgeColor: Theme.urgent
    text: SubmapService.submapName
}
