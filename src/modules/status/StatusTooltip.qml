pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../theme"
import "../../ui" as UI
import "../../services"
import "../../services/time/CalendarDates.mjs" as Dates

Column {
    id: root
    property var statusService: StatusService
    property string expandedDay: ""
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxPanelHeight: Math.max(0, Math.min((monitor?.height ?? 1080) * Theme.statusTooltipMaxHeightRatio,
        (monitor?.height ?? 1080) - Theme.barHeight - Theme.tooltipPaddingHeight * 2))
    readonly property bool managing: tabs.currentIndex === 3
    readonly property bool history: tabs.currentIndex === 2
    property string historyKind: "week"
    property date historyAnchor: Dates.shift(new Date(), "week", -1)
    readonly property date historyDate: Dates.start(historyAnchor, historyKind)
    readonly property var historyPeriods: statusService.recordedPeriods[historyKind]
    readonly property bool hasHistory: historyPeriods.length > 0
    property bool pickerExpanded: false
    readonly property date reportNow: new Date(TimeService.time)
    readonly property date earliest: new Date((statusService.recordedPeriods.first || Dates.key(reportNow)) + "T00:00:00")
    readonly property bool partialHistory: history && Dates.start(historyDate, historyKind) < earliest
    readonly property bool nativeDialogOpen: rulesEditor.nativeDialogOpen
    readonly property bool interactionPending: managing && rulesEditor.dirty
    readonly property string selectedReport: {
        switch(tabs.currentIndex) {
            case 0:return statusService.todayTimecard
            case 1:return statusService.currentWeekTimecard
            case 2:return statusService.periodReport(historyKind, historyDate)
            default:return ''
        }
    }
    readonly property var period: Timecard.parse(selectedReport)
    readonly property bool ranged: tabs.currentIndex > 0
    readonly property bool weekly: tabs.currentIndex === 1 || (history && historyKind === "week")
    readonly property color modeColor: statusService.status === "work" ? Theme.accent : statusService.status === "personal" ? Theme.active : Theme.inactive
    width: Math.min(Theme.statusTooltipWidth, (monitor?.width ?? Theme.statusTooltipWidth + Theme.tooltipPaddingWidth * 2)
        - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.controlSpacing
    Component.onCompleted: { statusService.beginPanel(); ensureHistorySelection() }
    Component.onDestruction: statusService.endPanel()
    function canMovePeriod(delta) {
        return !!adjacentPeriod(delta)
    }
    function adjacentPeriod(delta) {
        return Dates.adjacent(historyPeriods,Dates.key(historyDate),delta)
    }
    function movePeriod(delta) {
        const next = adjacentPeriod(delta)
        if (next) selectPeriod(new Date(next + "T12:00:00"))
    }
    function ensureHistorySelection() {
        if (!hasHistory) { pickerExpanded = false; return }
        if (!historyPeriods.includes(Dates.key(historyDate)))
            selectPeriod(new Date(historyPeriods[historyPeriods.length - 1] + "T12:00:00"))
    }
    function selectPeriod(date) {
        const key = Dates.key(Dates.start(date,historyKind))
        if (!historyPeriods.includes(key)) return
        const recorded = statusService.recordedPeriods.dates.find(day => Dates.key(Dates.start(new Date(day + "T12:00:00"),historyKind)) === key)
        historyAnchor = new Date(recorded + "T12:00:00")
        if (pickerExpanded) choosePeriod.forceActiveFocus(Qt.OtherFocusReason)
        pickerExpanded = false
        expandedDay = ""
        timecard.contentY = 0
    }
    onHistoryKindChanged: {
        ensureHistorySelection()
        periodPicker.revealSelection()
    }
    onHistoryPeriodsChanged: Qt.callLater(root.ensureHistorySelection)

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
                    text: Translations.text(["work","personal"].includes(root.statusService.status) ? "status.modes."+root.statusService.status : "common.states.unknown")
                    color: root.modeColor
                }
            }
            UI.ActionButton {
                id: refresh
                objectName: "refreshTimecard"
                keyAction: "refresh"
                anchors.right: modes.left
                anchors.rightMargin: Theme.controlSpacing
                glyph: Theme.refreshIcon
                hint: Translations.text("status.actions.refreshHint")
                enabled: !root.statusService.timecardLoading
                onClicked: root.statusService.reload()
            }
            Row {
                id: modes
                anchors.right: parent.right
                spacing: Theme.controlSpacing
                Repeater {
                    model: ["work", "personal"]
                    UI.ActionButton {
                        required property string modelData
                        readonly property bool selected: root.statusService.source === "manual"
                            && root.statusService.status === modelData
                        objectName: "setStatusMode-" + modelData
                        glyph: modelData === "work" ? Theme.statusWorkingIcon : Theme.statusPersonalIcon
                        hint: selected ? Translations.text("status.actions.automaticHint")
                            : Translations.text("status.actions.setMode",[Translations.text("status.modes."+modelData)])
                        foreground: root.statusService.status === modelData
                            ? (selected ? Theme.warning : Theme.accent) : Theme.text
                        fillColor: selected ? Theme.selectionSelectedBackground : Theme.alternateBackground
                        enabled: !root.statusService.changingStatus
                        onClicked: root.statusService.toggleStatus(modelData)
                    }
                }
            }
        }

        UI.TabBar {
            id: tabs
            objectName: "statusTimecardTabs"
            width: parent.width
            tabPadding: Theme.controlFieldPadding
            labels: [Translations.text("calendar.relative.today"), Translations.text("status.tabs.thisWeek"), Translations.text("status.tabs.history"), Translations.text("common.tabs.manage")]
            onCurrentIndexChanged: {
                root.expandedDay = ""
                root.pickerExpanded = false
                root.statusService.showPeriod(currentIndex)
                timecard.contentY = 0
            }
        }
        Row {
            visible: root.history
            width: parent.width
            spacing: Theme.controlSpacing
            UI.ComboSelector {
                objectName: "statusHistoryKind"
                width: Theme.controlHeight * 3
                compact: true
                options: [{name:"week",description:Translations.text("status.history.week")},
                    {name:"month",description:Translations.text("status.history.month")}]
                selectedName: root.historyKind
                enabled: root.hasHistory
                onSelected: name => root.historyKind = name
            }
            UI.ActionButton {
                objectName: "statusHistoryPrevious"
                glyph: Theme.chevronLeftIcon
                hint: Translations.text("common.actions.previous")
                enabled: root.canMovePeriod(-1)
                onClicked: root.movePeriod(-1)
            }
            UI.ActionButton {
                id: choosePeriod
                objectName: "statusHistoryChoose"
                width: heading.width - Theme.controlHeight * 3 - Theme.actionButtonWidth * 2 - Theme.controlSpacing * 3
                label: root.period.range || Translations.text("status.report.empty")
                enabled: root.hasHistory
                glyph: Theme.chevronDownIcon
                hint: Translations.text("status.history.choose")
                onClicked: {
                    root.pickerExpanded = !root.pickerExpanded
                    if (root.pickerExpanded) periodPicker.revealSelection()
                }
            }
            UI.ActionButton {
                objectName: "statusHistoryNext"
                glyph: Theme.chevronRightIcon
                hint: Translations.text("common.actions.next")
                enabled: root.canMovePeriod(1)
                onClicked: root.movePeriod(1)
            }
        }
        UI.CalendarPeriodPicker {
            id: periodPicker
            objectName: "statusHistoryPicker"
            width: parent.width
            visible: root.history && root.pickerExpanded
            kind: root.historyKind
            selectedDate: root.historyDate
            periods: root.historyPeriods
            today: root.reportNow
            onSelected: date => root.selectPeriod(date)
            Keys.onPressed: event => UI.Keybinds.handleCancel(event, () => { root.pickerExpanded = false; choosePeriod.forceActiveFocus() })
        }
        UI.ColumnText {
            width: parent.width
            visible: root.hasHistory && root.partialHistory
            text: Translations.text("status.history.partial",[Dates.key(root.earliest)])
            color: Theme.inactive
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
        UI.ColumnText {
            width: parent.width
            visible: !root.managing && !root.history
            text: root.ranged ? root.period.range : new Date(root.statusService.timecardDate + "T12:00:00").toLocaleDateString(Translations.locale, "dddd yyyy-MM-dd")
            color: Theme.inactive
            horizontalAlignment: Text.AlignHCenter
        }
        Row {
            visible: !root.managing
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
                        text: Translations.text(parent.modelData === "work" ? "status.modes.work" : "status.modes.personal")
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
            text: root.statusService.timecardError || (root.statusService.timecardLoading && !root.selectedReport ? Translations.text("status.report.loading") : "")
            color: root.statusService.timecardError ? Theme.warning : Theme.inactive
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        Rectangle { width: parent.width; height: 1; color: Theme.empty; visible: !root.managing }
    }

    StatusRulesEditor { id:rulesEditor; width:parent.width; visible:root.managing; statusService:root.statusService }
    UI.ColumnText { width:parent.width; text:root.statusService.pauseReason ?? ""; visible:!!text; color:Theme.inactive; wrapMode:Text.Wrap }
    Flickable {
        id: timecard
        property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: timecard }
        visible: !root.managing
        objectName: "statusTimecardView"
        width: root.width + Theme.scrollbarGutter
        height: Math.min(contentHeight, Math.max(0, root.maxPanelHeight - heading.height - root.spacing))
        contentWidth: width
        contentHeight: entries.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: entries
            width: root.width
            spacing: Theme.controlSpacing

            UI.ColumnText {
                width: parent.width
                visible: root.period.days.length === 0 && !root.statusService.timecardLoading && !root.statusService.timecardError
                text: Translations.text("status.report.empty")
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
                            anchors.leftMargin: dayToggle.leftPadding
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, Math.max(0, dayTotals.x - x - Theme.controlSpacing))
                            elide: Text.ElideRight
                            text: new Date(day.modelData.date + "T12:00:00").toLocaleDateString(Translations.locale, root.weekly ? "dddd" : root.ranged ? "yyyy-MM-dd" : "dddd yyyy-MM-dd")
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
                            anchors.right: parent.right
                            anchors.rightMargin: dayToggle.rightPadding + Theme.controlSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: Timecard.duration(day.modelData.work) + " / " + Timecard.duration(day.modelData.personal)
                            color: Theme.inactive
                            UI.HoverTooltip { text: Translations.text("status.report.legend") }
                        }
                        UI.CollapsibleSection {
                            id: dayToggle
                            objectName: "statusDay_" + day.modelData.date
                            anchors.fill: parent
                            padding: 0
                            chevronColor: enabled ? Theme.inactive : Theme.empty
                            expanded: day.expanded
                            enabled: day.modelData.blocks.length > 0
                            Accessible.name: day.modelData.date
                            contentItem: Item {}
                            background: Rectangle {
                                color: "transparent"
                                radius: Theme.iconButtonRadius
                                border.width: dayToggle.keyboardFocusVisible ? 1 : 0
                                border.color: Theme.accent
                            }
                            onExpansionRequested: expanded => root.expandedDay = expanded ? day.modelData.date : ""
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
                    Column {
                        width: day.width
                        visible: day.expanded
                        spacing: Theme.statusSessionRowSpacing
                        Repeater {
                            model: day.expanded ? day.modelData.blocks : []
                            delegate: SessionRow { required property var modelData; block: modelData; width: day.width }
                        }
                    }
                }
            }
            StatusDetectionSection {
                width: entries.width
                visible: !root.ranged
                statusService: root.statusService
            }
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
    }

    component SessionRow: Item {
        id: session
        required property var block
        objectName: "statusSession"
        height: Theme.statusSessionRowHeight
        UI.ColumnText {
            id: times
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.4
            text: session.block.start.slice(0, 5) + "–" + (session.block.ongoing ? Translations.text("common.states.now") : session.block.end.slice(0, 5))
            color: Theme.inactive
            UI.HoverTooltip { text: session.block.start + "–" + session.block.end }
        }
        UI.ColumnText {
            anchors.left: times.right
            anchors.right: duration.left
            anchors.verticalCenter: parent.verticalCenter
            text: Translations.text(session.block.category === "work" ? "status.modes.work" : "status.modes.personal")
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
