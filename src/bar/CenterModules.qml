import QtQuick
import "../modules/clock"
import "../modules/system"
import "../modules/updates"
Row {
    id: root
    required property var window
    Updates { centerTooltip: true }
    Clock { centerTooltip: true }
    RecentFiles { window: root.window; centerTooltip: true }
}
