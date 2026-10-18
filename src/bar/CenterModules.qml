import QtQuick
import "../modules/clock"
import "../modules/system"
import "../modules/updates"
import "../theme"
Row {
    id: root
    required property var window
    spacing: Theme.centerModulesSpacing
    Updates { centerTooltip: true }
    Clock { centerTooltip: true }
    RecentFiles { window: root.window; centerTooltip: true }
}
