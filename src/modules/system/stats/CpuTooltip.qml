pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import "../../../theme/ui" as UI
import "../../../services"
import "../../../theme"
import ".."

Column {
    id: root
    property var statsService: StatsService
    spacing: Theme.controlSpacing
    StatsBar { width: parent.width; label: Translations.text("stats.cpu.label"); value: root.statsService.cpu + "%"; ratio: root.statsService.cpu / 100 }
    Item {
        width: parent.width
        height: Theme.controlHeight
        UI.ColumnText { text: Translations.text("stats.cpu.temperature"); color: Theme.inactive }
        UI.ColumnText { anchors.right: parent.right; text: Number.isFinite(root.statsService.temperature) ? Math.round(root.statsService.temperature) + "°C" : Translations.text("common.states.unavailable") }
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
                label: Translations.text("stats.cpu.core",[index+1])
                value: modelData + "%"
                ratio: modelData / 100
            }
        }
    }
}
