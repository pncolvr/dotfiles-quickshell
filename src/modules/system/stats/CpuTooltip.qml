import QtQuick
import "../../../theme/ui" as UI
import "../../../services"
import "../../../theme"

Column {
    Repeater {
        model: StatsService.cores
        delegate: Row {
            id: root
            required property int modelData
            required property int index

            UI.ColumnText {
                width: Theme.cpuTooltipLabelWidth
                text: `core${String(root.index + 1).padStart(2, '0')}`
            }
            UI.ColumnText {
                width: Theme.cpuTooltipValueWidth
                horizontalAlignment: Text.AlignRight
                text: `${root.modelData}%`
            }
        }
    }
}