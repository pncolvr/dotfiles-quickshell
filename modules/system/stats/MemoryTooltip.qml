import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Column {
    id: root
    width: Theme.memoryTooltipWidth
    spacing: 6

    function barColor(colors, used, total) {
        const ratio = total > 0 ? used / total : 0
        const i = Math.min(colors.length - 1, Math.floor(ratio * colors.length))
        return colors[i]
    }

    UI.ColumnText {
        horizontalAlignment: Text.AlignLeft
        text: "memory"
    }

    Rectangle {
        width: parent.width
        height: 6
        radius: 3
        color: Theme.memoryTooltipMemFreeColor

        Rectangle {
            width: parent.width * (StatsService.memoryUsed / StatsService.memoryTotal)
            height: parent.height
            radius: parent.radius
            color: root.barColor(Theme.memoryTooltipMemColors, StatsService.memoryUsed, StatsService.memoryTotal)
        }
    }

    UI.ColumnText {
        horizontalAlignment: Text.AlignLeft
        text: "swap"
    }

    Rectangle {
        width: parent.width
        height: 6
        radius: 3
        color: Theme.memoryTooltipSwapFreeColor

        Rectangle {
            width: parent.width * (StatsService.swapTotal > 0 ? StatsService.swapUsed / StatsService.swapTotal : 0)
            height: parent.height
            radius: parent.radius
            color: root.barColor(Theme.memoryTooltipSwapColors, StatsService.swapUsed, StatsService.swapTotal)
        }
    }
}