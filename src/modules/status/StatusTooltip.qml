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
    property string expandedDay: ""
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxPanelHeight: Math.max(0, Math.min((monitor?.height ?? 1080) * Theme.statusTooltipMaxHeightRatio,
        (monitor?.height ?? 1080) - Theme.barHeight - Theme.tooltipPaddingHeight * 2))
    readonly property string selectedReport: tabs.currentIndex === 0 ? statusService.todayTimecard
        : tabs.currentIndex === 1 ? statusService.currentWeekTimecard
        : tabs.currentIndex === 2 ? statusService.lastWeekTimecard
        : tabs.currentIndex === 3 ? statusService.currentMonthTimecard : statusService.lastMonthTimecard
    readonly property var period: Timecard.parse(selectedReport)
    readonly property bool ranged: tabs.currentIndex > 0
    readonly property bool weekly: tabs.currentIndex === 1 || tabs.currentIndex === 2
    readonly property color modeColor: statusService.status === "work" ? Theme.accent : statusService.status === "personal" ? Theme.active : Theme.inactive
    width: Math.min(Theme.statusTooltipWidth, (monitor?.width ?? Theme.statusTooltipWidth + Theme.tooltipPaddingWidth * 2)
        - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.controlSpacing
    Component.onCompleted: statusService.beginPanel()
    Component.onDestruction: statusService.endPanel()

    Column {
        id: heading
        width: parent.width
        spacing: root.spacing

        Item {
            width: parent.width
            height: Theme.controlHeight
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.controlSpacing
                UI.IconText {
                    text: root.statusService.status === "work" ? Theme.statusWorkingIcon
                        : root.statusService.status === "personal" ? Theme.statusPersonalIcon : Theme.statusUnknownIcon
                    color: root.modeColor
                }
                UI.ColumnText {
                    text: root.statusService.status === "work" ? "Work" : root.statusService.status === "personal" ? "Personal" : "Unknown"
                    color: root.modeColor
                }
            }
            UI.ColumnText {
                anchors.right: refresh.left
                anchors.rightMargin: Theme.controlSpacing
                anchors.verticalCenter: parent.verticalCenter
                text: root.statusService.source === "manual" ? "Manual" : root.statusService.source === "automatic" ? "Automatic" : ""
                color: root.statusService.source === "manual" ? Theme.warning : Theme.inactive
            }
            UI.ActionButton {
                id: refresh
                objectName: "refreshTimecard"
                anchors.right: toggle.left
                anchors.rightMargin: Theme.controlSpacing
                glyph: Theme.refreshIcon
                hint: "Recheck mode and refresh timecard"
                enabled: !root.statusService.timecardLoading
                onClicked: root.statusService.reload()
            }
            UI.ActionButton {
                id: toggle
                objectName: "toggleStatusMode"
                anchors.right: reset.left
                anchors.rightMargin: Theme.controlSpacing
                glyph: root.statusService.status === "work" ? Theme.statusPersonalIcon : Theme.statusWorkingIcon
                hint: "Switch to " + (root.statusService.status === "work" ? "Personal" : "Work") + " (manual)"
                onClicked: root.statusService.toggle()
            }
            UI.ActionButton {
                id: reset
                objectName: "resetStatusMode"
                anchors.right: parent.right
                glyph: Theme.cancelIcon
                hint: "Reset to automatic detection"
                enabled: root.statusService.source === "manual"
                onClicked: root.statusService.clear()
            }
        }

        UI.TabBar {
            id: tabs
            objectName: "statusTimecardTabs"
            width: parent.width
            tabPadding: Theme.controlFieldPadding
            labels: ["Today", "This week", "Last week", "This month", "Last month"]
            onCurrentIndexChanged: {
                root.expandedDay = ""
                root.statusService.showPeriod(currentIndex)
                timecard.contentY = 0
            }
        }
        UI.ColumnText {
            width: parent.width
            text: root.ranged ? root.period.range : Qt.formatDate(new Date(root.statusService.timecardDate + "T12:00:00"), "dddd yyyy-MM-dd")
            color: Theme.inactive
            horizontalAlignment: Text.AlignHCenter
        }
        Row {
            width: parent.width
            spacing: Theme.controlSpacing
            Repeater {
                model: ["work", "personal"]
                delegate: Column {
                    required property string modelData
                    width: (heading.width - Theme.controlSpacing) / 2
                    spacing: 2
                    UI.ColumnText {
                        width: parent.width
                        text: parent.modelData === "work" ? "Work" : "Personal"
                        color: parent.modelData === "work" ? Theme.accent : Theme.active
                        horizontalAlignment: Text.AlignHCenter
                    }
                    UI.ColumnText {
                        objectName: parent.modelData === "work" ? "statusWorkTotal" : "statusPersonalTotal"
                        width: parent.width
                        text: Timecard.duration(root.period[parent.modelData])
                        font.pixelSize: Theme.fontSize * 1.5
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
        UI.ColumnText {
            id: feedback
            objectName: "statusTimecardFeedback"
            width: parent.width
            visible: text.length > 0
            text: root.statusService.timecardError || (root.statusService.timecardLoading && !root.selectedReport ? "Loading timecard…" : "")
            color: root.statusService.timecardError ? Theme.warning : Theme.inactive
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        Rectangle { width: parent.width; height: 1; color: Theme.empty }
    }

    Flickable {
        id: timecard
        objectName: "statusTimecardView"
        width: parent.width
        height: Math.min(contentHeight, Math.max(0, root.maxPanelHeight - heading.height - root.spacing))
        contentWidth: width
        contentHeight: entries.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: entries
            width: timecard.width
            spacing: Theme.controlSpacing

            UI.ColumnText {
                width: parent.width
                visible: root.period.days.length === 0 && !root.statusService.timecardLoading && !root.statusService.timecardError
                text: "No activity recorded."
                color: Theme.inactive
                horizontalAlignment: Text.AlignHCenter
            }
            Repeater {
                model: root.period.days
                delegate: Column {
                    id: day
                    required property var modelData
                    width: entries.width
                    spacing: Theme.controlSpacing
                    readonly property bool expanded: root.expandedDay === modelData.date
                    readonly property real total: modelData.work + modelData.personal

                    Item {
                        width: parent.width
                        height: Theme.controlHeight
                        UI.ColumnText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, Math.max(0, dayTotals.x - Theme.controlSpacing))
                            elide: Text.ElideRight
                            text: Qt.formatDate(new Date(day.modelData.date + "T12:00:00"), root.weekly ? "dddd" : root.ranged ? "yyyy-MM-dd" : "dddd yyyy-MM-dd")
                            HoverHandler {
                                id: dateHover
                                cursorShape: day.modelData.blocks.length ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                            UI.HoverTooltip {
                                enabled: root.weekly
                                hoverTarget: dateHover
                                text: day.modelData.date
                            }
                        }
                        UI.ColumnText {
                            id: dayTotals
                            anchors.right: expand.left
                            anchors.rightMargin: Theme.controlSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: Timecard.duration(day.modelData.work) + " / " + Timecard.duration(day.modelData.personal)
                            color: Theme.inactive
                            UI.HoverTooltip { text: "Work / Personal" }
                        }
                        UI.IconText {
                            id: expand
                            anchors.right: parent.right
                            text: Theme.chevronDownIcon
                            rotation: day.expanded ? 180 : 0
                            color: day.modelData.blocks.length ? Theme.inactive : Theme.empty
                        }
                        MouseArea {
                            objectName: "statusDay_" + day.modelData.date
                            anchors.fill: parent
                            enabled: day.modelData.blocks.length > 0
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expandedDay = day.expanded ? "" : day.modelData.date
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.empty
                        clip: true
                        Rectangle {
                            width: day.total > 0 ? parent.width * day.modelData.work / day.total : 0
                            height: parent.height
                            color: Theme.accent
                        }
                        Rectangle {
                            anchors.right: parent.right
                            width: day.total > 0 ? parent.width * day.modelData.personal / day.total : 0
                            height: parent.height
                            color: Theme.active
                        }
                    }
                    Repeater {
                        model: day.expanded ? day.modelData.blocks : []
                        delegate: SessionRow { required property var modelData; block: modelData; width: day.width }
                    }
                }
            }
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
    }

    component SessionRow: Item {
        id: session
        required property var block
        objectName: "statusSession"
        height: Theme.controlHeight
        UI.ColumnText {
            id: times
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.4
            text: session.block.start.slice(0, 5) + "–" + (session.block.ongoing ? "now" : session.block.end.slice(0, 5))
            color: Theme.inactive
            UI.HoverTooltip { text: session.block.start + "–" + session.block.end }
        }
        UI.ColumnText {
            anchors.left: times.right
            anchors.right: duration.left
            anchors.verticalCenter: parent.verticalCenter
            text: session.block.category === "work" ? "Work" : "Personal"
            color: session.block.category === "work" ? Theme.accent : Theme.active
        }
        UI.ColumnText {
            id: duration
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Timecard.duration(session.block.duration)
        }
    }
}
