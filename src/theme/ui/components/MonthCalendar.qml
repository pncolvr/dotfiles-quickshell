pragma ComponentBehavior: Bound

import "../../../i18n"
import QtQuick
import "../" as UI
import "../../"
import "../../../services"
import "../../../services/time/CalendarDates.mjs" as Dates

Item {
    id: root
    width: Theme.calendarWidth
    height: col.implicitHeight

    property bool weekSelection: false
    property date selectedWeek: new Date()
    property var availableWeeks: []
    signal weekSelected(date week)
    signal daySelected(date day)
    property bool wheelEnabled: true
    property bool showYearTitle: true
    property bool showTitle: true

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

    function isTodayWeekday(index) {
        return _internal.todayWeekDay === index
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
            visible: root.showTitle
            width: parent.width
            text: Translations.calendarMonthNames[root.displayMonth] + (root.showYearTitle ? ` ${root.displayYear}` : '')
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
                model: Translations.calendarDayNames
                UI.ColumnText {
                    required property string modelData
                    required property int index
                    width: Theme.calendarCellWidth
                    text: modelData
                    color: root.isTodayWeekday(index) ? Theme.accent : Theme.calendarHeaderText
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Weeks
        Repeater {
            model: 6
            delegate: Item {
                id: weekRow
                required property int index
                width: parent.width
                height: Theme.calendarCellHeight

                property int weekOffset: Dates.firstDayOfMonth(root.displayMonth, root.displayYear)
                property int firstDayOfWeek: index * 7 - weekOffset + 1
                property date weekDate: new Date(root.displayYear, root.displayMonth, firstDayOfWeek)
                property bool weekVisible: firstDayOfWeek <= Dates.daysInMonth(root.displayMonth, root.displayYear)

                visible: weekVisible || index === 0

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.calendarCellRadius
                    visible: root.weekSelection
                    color: Dates.key(root.selectedWeek) === Dates.key(weekRow.weekDate) ? Theme.selectionSelectedBackground
                        : weekMouse.containsMouse ? Theme.selectionHoverBackground : "transparent"
                    opacity: weekMouse.enabled ? 1 : 0.45
                    border.width: weekMouse.activeFocus ? 1 : 0
                    border.color: Theme.accent
                }
                Row {
                    spacing: Theme.calendarSpacing
                    UI.ColumnText {
                        width: Theme.calendarCellWidth
                        height: width
                        text: weekRow.weekVisible ? Dates.weekNumber(weekRow.weekDate) : ""
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
                            property bool valid: dayNum >= 1 && dayNum <= Dates.daysInMonth(root.displayMonth, root.displayYear)
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
                                enabled: day.valid && !root.weekSelection
                                cursorShape: Qt.PointingHandCursor
                                text: day.valid ? CalendarService.dayTooltip(day.date) : ""
                                delay: Theme.calendarDayTooltipDelay
                                onClicked: root.daySelected(day.date)
                            }
                        }
                    }
                }
                MouseArea {
                    id: weekMouse
                    objectName: "calendarWeek-" + Dates.key(weekRow.weekDate)
                    anchors.fill: parent
                    visible: root.weekSelection
                    enabled: root.weekSelection && root.availableWeeks.includes(Dates.key(weekRow.weekDate))
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    activeFocusOnTab: enabled
                    onClicked: root.weekSelected(weekRow.weekDate)
                    Keys.onReturnPressed: root.weekSelected(weekRow.weekDate)
                    Keys.onEnterPressed: root.weekSelected(weekRow.weekDate)
                    Keys.onSpacePressed: root.weekSelected(weekRow.weekDate)
                }
            }
        }
    }
}
