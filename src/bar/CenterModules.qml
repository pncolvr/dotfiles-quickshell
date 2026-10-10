import QtQuick
import "../modules/clock"
import "../modules/system"
import "../modules/updates"

Row {
    id: root
    required property var window
    // spacing: Theme.moduleSpacing
    spacing: 8
    Updates { moduleName: "updates"; centerTooltip: true }
    Clock { moduleName: "clock"; centerTooltip: true }
    RecentFiles { moduleName: "files"; window: root.window; centerTooltip: true }
}
