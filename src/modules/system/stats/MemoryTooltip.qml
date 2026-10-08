pragma ComponentBehavior: Bound
import QtQuick
import "../../../theme"
import ".."
import "../../../theme/ui" as UI
import "../../../services"

Column {
    id: root
    property var statsService: StatsService
    spacing: Theme.controlSpacing
    function size(mib) { return mib >= 1024 ? (mib / 1024).toFixed(1) + " GiB" : Math.round(mib) + " MiB" }
    StatsBar {
        width: parent.width
        label: "RAM"
        value: root.size(root.statsService.memoryUsed) + " / " + root.size(root.statsService.memoryTotal)
        ratio: root.statsService.memoryTotal > 0 ? root.statsService.memoryUsed / root.statsService.memoryTotal : 0
    }
    Repeater {
        model: ["Free", "Available", "Cached"]
        Item {
            required property string modelData
            width: root.width
            height: Theme.controlHeight
            UI.ColumnText { text: parent.modelData; color: Theme.inactive }
            UI.ColumnText {
                anchors.right: parent.right
                text: root.size(parent.modelData === "Free" ? root.statsService.memoryFree
                    : parent.modelData === "Available" ? root.statsService.memoryAvailable : root.statsService.memoryCache)
            }
        }
    }
    StatsBar {
        width: parent.width
        label: "Swap"
        value: root.statsService.swapTotal > 0 ? root.size(root.statsService.swapUsed) + " / " + root.size(root.statsService.swapTotal) : "Disabled"
        ratio: root.statsService.swapTotal > 0 ? root.statsService.swapUsed / root.statsService.swapTotal : 0
        fillColor: Theme.warning
    }
}
