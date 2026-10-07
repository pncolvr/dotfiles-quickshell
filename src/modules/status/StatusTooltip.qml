pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../theme"
import "../../theme/ui" as UI
import "../../services"

Column {
    id: root
    property var statusService: StatusService
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxPanelHeight: Math.max(0, Math.min((monitor?.height ?? 1080) * Theme.statusTooltipMaxHeightRatio,
        (monitor?.height ?? 1080) - Theme.barHeight - Theme.tooltipPaddingHeight * 2))
    width: Math.min(Theme.statusTooltipWidth, (monitor?.width ?? Theme.statusTooltipWidth + Theme.tooltipPaddingWidth * 2)
        - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.controlSpacing
    Component.onCompleted: statusService.beginPanel()
    Component.onDestruction: statusService.endPanel()

    Item {
        id: header
        width: parent.width
        height: Theme.controlHeight
        UI.Text {
            anchors.left: parent.left
            anchors.right: refresh.left
            anchors.rightMargin: Theme.controlSpacing
            elide: Text.ElideRight
            text: (root.statusService.status || "Unknown") + " mode"
                + (root.statusService.source === "automatic" ? " · detected"
                    : root.statusService.source === "manual" ? " · manually set" : "")
            color: root.statusService.source === "manual" ? Theme.warning : Theme.text
        }
        UI.ActionButton {
            id: refresh
            objectName: "refreshTimecard"
            anchors.right: parent.right
            glyph: Theme.refreshIcon
            hint: "Refresh timecard"
            enabled: !root.statusService.timecardLoading
            onClicked: root.statusService.refreshTimecard()
        }
    }
    UI.ColumnText {
        id: todayLabel
        width: parent.width
        text: "Today · " + root.statusService.timecardDate
        color: Theme.inactive
    }
    UI.ColumnText {
        id: summary
        objectName: "statusSummary"
        width: parent.width
        text: root.statusService.summary
        textFormat: Text.PlainText
        visible: text.length > 0
    }
    UI.ColumnText {
        id: feedback
        objectName: "statusTimecardFeedback"
        width: parent.width
        visible: text.length > 0
        text: root.statusService.timecardError || (root.statusService.timecardLoading && !root.statusService.summary
            ? "Loading timecard…" : "")
        color: root.statusService.timecardError ? Theme.warning : Theme.inactive
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    UI.TabBar {
        id: tabs
        objectName: "statusTimecardTabs"
        width: parent.width
        labels: ["Today", "Current week", "Last week"]
        onCurrentIndexChanged: root.statusService.showWeeks(currentIndex > 0)
    }
    Flickable {
        id: timecard
        objectName: "statusTimecardView"
        width: parent.width
        height: Math.min(contentHeight, Math.max(0, root.maxPanelHeight - header.height - todayLabel.height - tabs.height
            - (summary.visible ? summary.height + root.spacing : 0)
            - (feedback.visible ? feedback.height + root.spacing : 0) - root.spacing * 3))
        contentWidth: Math.max(width, report.implicitWidth)
        contentHeight: report.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onContentHeightChanged: { contentY = 0; contentX = 0 }
        UI.ColumnText {
            id: report
            objectName: "statusTimecardReport"
            text: tabs.currentIndex === 0 ? root.statusService.todayTimecard
                : (tabs.currentIndex === 1 ? root.statusService.currentWeekTimecard : root.statusService.lastWeekTimecard)
                    || (root.statusService.timecardLoading ? "Loading timecard…" : "No completed time blocks found.")
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
        QC.ScrollBar.horizontal: UI.ScrollBar {}
    }
}
