pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import "../../../theme"
import "../../../ui" as UI
import ".."
import "../../../services"

Column {
    id: root
    property var statsService: StatsService
    spacing: Theme.controlSpacing
    function size(mib) { return mib >= 1024 ? (mib / 1024).toFixed(1) + " GiB" : Math.round(mib) + " MiB" }
    MemoryBar { width: parent.width; statsService: root.statsService }
    StatsBar {
        objectName: "statsSwapBar"
        width: parent.width
        label: Translations.text("stats.memory.swap")
        value: root.statsService.swapTotal > 0 ? root.size(root.statsService.swapUsed) + " / " + root.size(root.statsService.swapTotal) : Translations.text("common.states.disabled")
        ratio: root.statsService.swapTotal > 0 ? root.statsService.swapUsed / root.statsService.swapTotal : 0
        fillColor: Theme.warning
    }
    Repeater {
        model: ["Free", "Available", "Cached"]
        Item {
            required property string modelData
            width: root.width
            height: Math.max(detailLabel.implicitHeight, detailValue.implicitHeight)
            UI.ColumnText { id: detailLabel; text: Translations.text(({Free:"stats.memory.free", Available:"stats.memory.available", Cached:"stats.memory.cached"})[parent.modelData]); color: Theme.inactive }
            UI.ColumnText {
                id: detailValue
                objectName: "statsMemory" + parent.modelData
                anchors.right: parent.right
                text: {
                    switch (parent.modelData) {
                    case "Free": return root.size(root.statsService.memoryFree)
                    case "Available": return root.size(root.statsService.memoryAvailable)
                    case "Cached": return root.size(root.statsService.memoryCache)
                    default: return ""
                    }
                }
            }
        }
    }

}
