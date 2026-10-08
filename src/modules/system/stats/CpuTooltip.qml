pragma ComponentBehavior: Bound
import QtQuick
import "../../../theme/ui" as UI
import "../../../services"
import "../../../theme"
import ".."

Column {
    id: root
    property var statsService: StatsService
    spacing: Theme.controlSpacing
    StatsBar { width: parent.width; label: "CPU"; value: root.statsService.cpu + "%"; ratio: root.statsService.cpu / 100 }
    Item {
        width: parent.width
        height: Theme.controlHeight
        UI.ColumnText { text: "Temperature"; color: Theme.inactive }
        UI.ColumnText { anchors.right: parent.right; text: Number.isFinite(root.statsService.temperature) ? Math.round(root.statsService.temperature) + "°C" : "Unavailable" }
    }
    Grid {
        width: parent.width
        columns: 4
        spacing: Theme.controlSpacing
        Repeater {
            model: root.statsService.cores
            StatsBar {
                required property int modelData
                required property int index
                width: (root.width - Theme.controlSpacing * 3) / 4
                label: "Core " + (index + 1)
                value: modelData + "%"
                ratio: modelData / 100
            }
        }
    }
}
