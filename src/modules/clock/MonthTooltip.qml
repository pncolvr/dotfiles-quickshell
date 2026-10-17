pragma ComponentBehavior: Bound

import QtQuick
import "../../theme/ui" as UI
import "../../theme"
import "../../services"

Item {
    id: root
    width: Theme.calendarWidth
    height: col.implicitHeight

    property bool wheelEnabled: true
    property bool showYearTitle: true

    property int displayMonth: new Date(TimeService.time).getMonth()
    property int displayYear: new Date(TimeService.time).getFullYear()

    QtObject {
        id: _internal
        property int todayWeekDay: (new Date(TimeService.time).getDay() + 6) % 7
        property int todayDay: new Date(TimeService.time).getDate()
        property int todayMonth: new Date(TimeService.time).getMonth()
        property int todayYear: new Date(TimeService.time).getFullYear()
    }

    function dayBackground(style) {
        switch (style) {
            case CalendarService.DayStyle.Today: return Theme.calendarTodayBackground
            case CalendarService.DayStyle.ClockChangeEve: return Theme.calendarClockChangeEveBackground
            case CalendarService.DayStyle.Holiday: return Theme.calendarHolidayBackground
            default: return "transparent"
        }
    }

    function dayForeground(style, weekend) {
        switch (style) {
            case CalendarService.DayStyle.Invalid: return "transparent"
            case CalendarService.DayStyle.Today: return Theme.calendarTodayText
            case CalendarService.DayStyle.Holiday: return Theme.calendarHolidayText
            case CalendarService.DayStyle.ClockChangeEve: return Theme.calendarClockChangeEveText
            default: return weekend ? Theme.calendarWeekendText : Theme.calendarDayText
        }
    }

    function daysInMonth(month, year) {
        return new Date(year, month + 1, 0).getDate()
    }

    function firstDayOfMonth(month, year) {
        let d = new Date(year, month, 1).getDay()
        return d === 0 ? 6 : d - 1
    }

    function weekNumber(date) {
        const d = new Date(date)
        d.setHours(0, 0, 0, 0)
        d.setDate(d.getDate() + 3 - (d.getDay() + 6) % 7)
        const week1 = new Date(d.getFullYear(), 0, 4)
        return 1 + Math.round(((d - week1) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7)
    }

    function isTodayWeekday(weekDayName) {
        return Theme.calendarDayNames[_internal.todayWeekDay] == weekDayName
    }

    WheelHandler {
        enabled: root.wheelEnabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y > 0) {
                if (root.displayMonth === 0) { root.displayMonth = 11; root.displayYear-- }
                else root.displayMonth--
            } else {
                if (root.displayMonth === 11) { root.displayMonth = 0; root.displayYear++ }
                else root.displayMonth++
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.calendarSpacing

        // Month header
        UI.ColumnText {
            width: parent.width
            text: Theme.calendarMonthNames[root.displayMonth] + (root.showYearTitle ? ` ${root.displayYear}` : '')
            color: Theme.calendarHeaderText
            horizontalAlignment: Text.AlignHCenter
        }

        // Day headers
        Row {
            width: parent.width
            spacing: Theme.calendarSpacing

            UI.ColumnText {
                width: Theme.calendarCellWidth
                text: ""
                color: Theme.calendarHeaderText
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: Theme.calendarDayNames
                UI.ColumnText {
                    required property string modelData
                    width: Theme.calendarCellWidth
                    text: modelData
                    color: root.isTodayWeekday(modelData) ? Theme.accent : Theme.calendarHeaderText
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Weeks
        Repeater {
            model: 6
            delegate: Row {
                id: weekRow
                required property int index
                width: parent.width
                height: Theme.calendarCellHeight
                spacing: Theme.calendarSpacing

                property int weekOffset: root.firstDayOfMonth(root.displayMonth, root.displayYear)
                property int firstDayOfWeek: index * 7 - weekOffset + 1
                property date weekDate: new Date(root.displayYear, root.displayMonth, firstDayOfWeek)
                property bool weekVisible: firstDayOfWeek <= root.daysInMonth(root.displayMonth, root.displayYear)

                visible: weekVisible || index === 0

                UI.ColumnText {
                    width: Theme.calendarCellWidth
                    height: width
                    text: weekRow.weekVisible ? root.weekNumber(weekRow.weekDate) : ""
                    color: Theme.calendarWeekNumberText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: 7
                    delegate: Rectangle {
                        id: day
                        required property int index
                        property int dayNum: weekRow.firstDayOfWeek + index
                        property bool isToday: dayNum === _internal.todayDay &&
                            root.displayMonth === _internal.todayMonth &&
                            root.displayYear === _internal.todayYear
                        property bool valid: dayNum >= 1 && dayNum <= root.daysInMonth(root.displayMonth, root.displayYear)
                        property date date: new Date(root.displayYear, root.displayMonth, dayNum)
                        property int style: CalendarService.dayStyle(date, valid, isToday)

                        width: Theme.calendarCellWidth
                        height: Theme.calendarCellHeight
                        radius: Theme.calendarCellRadius
                        color: root.dayBackground(style)

                        UI.ColumnText {
                            anchors.centerIn: parent
                            text: day.valid ? day.dayNum : ""
                            color: root.dayForeground(day.style, day.index >= 5)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                        }

                        UI.HoverTooltip {
                            enabled: day.valid
                            cursorShape: Qt.PointingHandCursor
                            text: day.valid ? CalendarService.dayTooltip(day.date) : ""
                            delay: Theme.calendarDayTooltipDelay
                            onClicked: CalendarService.openDate(day.date)
                        }
                    }
                }
            }
        }
    }
}
