pragma ComponentBehavior: Bound
import QtQuick
import "../../../i18n"
import "../../../services/time/CalendarDates.mjs" as Dates
import "../../"
import "../" as UI

Column {
    id: root
    property string kind: "week"
    property date selectedDate: new Date()
    property var periods: []
    property date today: new Date()
    property int displayYear: selectedDate.getFullYear()
    property int displayMonth: selectedDate.getMonth()
    readonly property var pages: [...new Set(periods.map(period => kind === "week" ? period.slice(0,7) : period.slice(0,4)))]
    signal selected(date date)
    spacing: Theme.controlSpacing
    function revealSelection() {
        displayYear = selectedDate.getFullYear()
        displayMonth = selectedDate.getMonth()
    }
    function adjacentPage(delta) {
        const current = String(displayYear) + (kind === "week" ? "-" + String(displayMonth + 1).padStart(2,"0") : "")
        return Dates.adjacent(pages,current,delta)
    }
    function browse(delta) {
        const page = adjacentPage(delta)
        if (!page) return
        displayYear = Number(page.slice(0,4))
        if (kind === "week") displayMonth = Number(page.slice(5,7)) - 1
    }
    function choose(date) {
        if (periods.includes(Dates.key(Dates.start(date,kind)))) selected(Dates.start(date,kind))
    }
    onKindChanged: revealSelection()
    Row {
        width: parent.width
        spacing: Theme.controlSpacing
        UI.ActionButton {
            objectName: "periodPickerPrevious"
            glyph: Theme.chevronLeftIcon
            hint: Translations.text("common.actions.previous")
            enabled: !!root.adjacentPage(-1)
            onClicked: root.browse(-1)
        }
        UI.ColumnText {
            width: parent.width - Theme.actionButtonWidth * 2 - parent.spacing * 2
            height: Theme.controlHeight
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: root.kind === "month" ? String(root.displayYear) : Translations.calendarMonthNames[root.displayMonth] + " " + root.displayYear
            color: Theme.calendarHeaderText
        }
        UI.ActionButton {
            objectName: "periodPickerNext"
            glyph: Theme.chevronRightIcon
            hint: Translations.text("common.actions.next")
            enabled: !!root.adjacentPage(1)
            onClicked: root.browse(1)
        }
    }
    Item {
        width: parent.width
        height: Math.max(root.kind === "week" ? calendar.height : months.height, todayButton.height)
        UI.MonthCalendar {
            id: calendar
            visible: root.kind === "week"
            anchors.horizontalCenter: parent.horizontalCenter
            displayYear: root.displayYear
            displayMonth: root.displayMonth
            showTitle: false
            weekSelection: true
            selectedWeek: Dates.start(root.selectedDate,"week")
            availableWeeks: root.periods
            wheelEnabled: false
            onWeekSelected: week => root.choose(week)
        }
        Grid {
            id: months
            visible: root.kind === "month"
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - (Theme.actionButtonWidth + Theme.controlSpacing) * 2
            columns: 3
            spacing: Theme.calendarSpacing
            Repeater {
                model: 12
                delegate: UI.ActionButton {
                    required property int index
                    readonly property date month: new Date(root.displayYear,index,1)
                    readonly property bool chosen: root.selectedDate.getFullYear() === root.displayYear && root.selectedDate.getMonth() === index
                    objectName: "periodPickerMonth-" + index
                    width: (months.width - Theme.calendarSpacing * 2) / 3
                    label: Translations.calendarMonthNames[index]
                    enabled: root.periods.includes(Dates.key(month))
                    fillColor: chosen ? Theme.selectionSelectedBackground : Theme.selectionBackground
                    onClicked: root.choose(month)
                }
            }
        }
        UI.ActionButton {
            id: todayButton
            objectName: "periodPickerToday"
            anchors.right: parent.right
            glyph: Theme.todayIcon
            hint: Translations.text("calendar.relative.today")
            enabled: root.periods.includes(Dates.key(Dates.start(root.today,root.kind)))
            onClicked: root.choose(root.today)
        }
    }
}
