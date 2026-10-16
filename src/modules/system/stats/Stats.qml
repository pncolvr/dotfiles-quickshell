import QtQuick
import "../../../theme/ui" as UI
import "../../../theme"
import ".."

UI.TooltipArea {
    moduleName: "stats"
    id: root
    acceptedButtons: Qt.LeftButton

    tooltipSource: root
    tooltip: Component { StatsTooltip {} }

    UI.BarIcon {
        objectName: "statsBarIcon"
        text: Theme.statsIcon
        color: root.moduleIconColor
    }
}
