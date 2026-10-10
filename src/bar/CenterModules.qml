import QtQuick
import "../modules/clock"
import "../modules/system"
import "../modules/updates"

Row {
    id: root
    required property var window
    // spacing: Theme.moduleSpacing
    spacing: 8
    Updates { centerTooltip: true }
    Clock { centerTooltip: true }
    RecentFiles { window: root.window; centerTooltip: true }
}
