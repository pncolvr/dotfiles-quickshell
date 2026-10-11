pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/config"
import "../../src/theme"
import "../../src/modules/clock"

Scope {
    id: root
    property bool failed: false
    property int step: 0
    // The runner supplies a writable TimeService clock in its isolated source copy.
    property var testClock: TimeService
    property var clockPanel: null
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    function calendarView(item) {
        if (item.displayYear !== undefined) return item
        for (const child of item.children ?? []) {
            const view = calendarView(child)
            if (view) return view
        }
        return null
    }
    function check(value, message) {
        if (!value) { failed = true; console.error("CALENDAR FAIL: " + message) }
    }
    function cells(item, result = []) {
        if (item.dayNum !== undefined) result.push(item)
        for (const child of item.children ?? []) cells(child, result)
        return result
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 720
        implicitHeight: 800
        MonthTooltip { id: month; displayYear: 2026; displayMonth: 9 }
        YearTooltip { id: year; visible: false; displayYear: 2027 }
        Clock { id: clock; visible: false }
    }
    Test.TestCase { id: events; name: "Clock calendar navigation"; when: false }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (root.step > 0) {
                switch (root.step++) {
                    case 20:
                        clock.visible = true
                        root.clockPanel = clock.tooltip.createObject(window.contentItem, {x: 0, y: 40})
                        root.check(root.find(root.clockPanel, "calendarColorLegend").showClockChangeEve,
                            "October month legend includes change eve")
                        root.check(root.find(root.clockPanel, "calendarColorLegend").showToday,
                            "current month includes today hint")
                        events.mouseClick(clock, clock.width / 2, clock.height / 2, Qt.RightButton)
                        return
                    case 21: {
                        const view = root.calendarView(root.clockPanel)
                        root.check(clock.viewMode === Clock.View.Year && view && view.displayMonth === undefined,
                            "right click opens actual annual tooltip")
                        root.check(root.find(root.clockPanel, "calendarColorLegend").showClockChangeEve,
                            "year legend includes change eve")
                        root.check(root.find(root.clockPanel, "calendarColorLegend").showToday,
                            "current year includes today hint")
                        if (!view) { Qt.quit(); return }
                        events.mouseWheel(view, view.width / 2, view.height / 2, 0, -120)
                        return
                    }
                    case 22: {
                        const view = root.calendarView(root.clockPanel)
                        root.check(view.displayYear === 2027, "scroll annual tooltip to 2027")
                        root.check(!root.find(root.clockPanel, "calendarColorLegend").showToday,
                            "other year omits today hint")
                        const warnings = root.cells(view).filter(cell => cell.valid && cell.style === CalendarService.DayStyle.ClockChangeEve)
                        root.check(warnings.length === 2
                            && warnings.some(cell => cell.date.getMonth() === 2 && cell.dayNum === 27)
                            && warnings.some(cell => cell.date.getMonth() === 9 && cell.dayNum === 30)
                            && warnings.every(cell => cell.color.toString() === Theme.warning.toString()),
                            "actual 2027 annual tooltip renders both warning dates")
                        events.mouseClick(clock, clock.width / 2, clock.height / 2, Qt.RightButton)
                        return
                    }
                    case 23: {
                        root.calendarView(root.clockPanel).displayMonth = 10
                        return
                    }
                    case 24: {
                        const legend = root.find(root.clockPanel, "calendarColorLegend")
                        root.check(!legend.showClockChangeEve && !legend.text.includes("Change eve"),
                            "November legend omits change eve")
                        root.check(!legend.text.includes("Today") && legend.text.includes("Holiday"),
                            "other month only shows its holiday hint")
                        root.check(legend.showHolidays && legend.visible, "November holiday hint is visible")
                        root.calendarView(root.clockPanel).displayMonth = 2
                        return
                    }
                    case 25: {
                        const legend = root.find(root.clockPanel, "calendarColorLegend")
                        root.check(legend.showClockChangeEve && legend.contentWidth <= legend.width,
                            "March legend includes change eve and fits one line")
                        root.check(!legend.showHolidays && !legend.text.includes("Holiday"),
                            "March 2026 omits absent holiday hint")
                        root.calendarView(root.clockPanel).displayMonth = 6
                        return
                    }
                    case 26: {
                        const legend = root.find(root.clockPanel, "calendarColorLegend")
                        root.check(!legend.showHolidays && !legend.showClockChangeEve && !legend.visible,
                            "July without holidays or clock changes hides all hints")
                        root.clockPanel.destroy()
                        clock.visible = false
                        root.step = 10
                        month.displayYear = 2030; month.displayMonth = 2
                        year.displayYear = 2030
                        return
                    }
                    case 10: {
                        const monthWarnings = root.cells(month).filter(cell => cell.valid && cell.style === CalendarService.DayStyle.ClockChangeEve)
                        root.check(monthWarnings.length === 1 && monthWarnings[0].dayNum === 30,
                            "changing month/year renders 2030 spring eve")
                        const yearWarnings = root.cells(year).filter(cell => cell.valid && cell.style === CalendarService.DayStyle.ClockChangeEve)
                        root.check(yearWarnings.length === 2
                            && yearWarnings.some(cell => cell.date.getMonth() === 2 && cell.dayNum === 30)
                            && yearWarnings.some(cell => cell.date.getMonth() === 9 && cell.dayNum === 26),
                            "changing annual view year renders both 2030 eves")
                        month.displayYear = 2025; month.displayMonth = 9
                        year.displayYear = 2025
                        return
                    }
                    case 11: {
                        const monthWarnings = root.cells(month).filter(cell => cell.valid && cell.style === CalendarService.DayStyle.ClockChangeEve)
                        root.check(monthWarnings.length === 1 && monthWarnings[0].dayNum === 25,
                            "changing backward renders 2025 autumn eve")
                        const yearWarnings = root.cells(year).filter(cell => cell.valid && cell.style === CalendarService.DayStyle.ClockChangeEve)
                        root.check(yearWarnings.length === 2
                            && yearWarnings.some(cell => cell.date.getMonth() === 2 && cell.dayNum === 29)
                            && yearWarnings.some(cell => cell.date.getMonth() === 9 && cell.dayNum === 25),
                            "changing annual view backward renders both 2025 eves")
                        root.check(CalendarService.dayTooltip(monthWarnings[0].date).includes("Clocks go back")
                            && !CalendarService.dayTooltip(monthWarnings[0].date).includes("2025-10-26"),
                            "navigated tooltip describes change without date")
                        month.displayYear = 2026; month.displayMonth = 9
                        root.step = 1
                        root.testClock.time = new Date(2026, 9, 24, 12).toString()
                        return
                    }
                    case 1:
                        root.check(CalendarService.clockChangeNotice.includes("tomorrow"), "live notice appears on eve")
                        root.check(root.cells(month).find(cell => cell.dayNum === 24).color.toString() === Theme.warning.toString(), "today's eve keeps warning background")
                        root.check((clock.child as Text).color.toString() === Theme.text.toString(), "bar color unchanged during warning")
                        root.testClock.time = new Date(2026, 9, 25, 0).toString()
                        return
                    case 2:
                        root.check(!CalendarService.clockChangeNotice, "live warning disappears at midnight before transition")
                        root.testClock.time = new Date(2027, 2, 27, 23, 59).toString()
                        return
                    case 3:
                        root.check(CalendarService.clockChangeNotice.includes("Clocks go forward tomorrow"), "resume into future eve updates warning")
                        root.testClock.time = new Date(2027, 2, 28, 0).toString()
                        return
                    default:
                        root.check(!CalendarService.clockChangeNotice, "future transition date clears notice")
                        if (!root.failed) console.log("PASS: calendar transitions, previous-day warning, styling and navigation")
                        Qt.quit()
                        return
                }
            }
            const current = CalendarService.transitionsFor(2026)
            const future = CalendarService.transitionsFor(2027)
            root.check(current.length === 2 && future.length === 2, "year calculations complete synchronously")
            root.check(CalendarService.transitionsFor(2026) === current, "year cache reused")
            root.check(CalendarService.transitionsFor(2001).length === 0, "pre-policy years are outside scope")
            root.check(current[1].date === "2026-10-25" && current[1].eve === "2026-10-24", "autumn dates")
            root.check(current[1].old.endsWith("02:00:00") && current[1].new.endsWith("01:00:00"), "autumn offsets")
            root.check(future[0].date === "2027-03-28" && future[0].eve === "2027-03-27", "future spring dates")
            const eve = new Date(2026, 9, 24, 12)
            const change = new Date(2026, 9, 25, 12)
            const before = new Date(2026, 9, 23, 12)
            root.check(CalendarService.warningFor(eve).includes("tomorrow")
                && CalendarService.warningFor(eve).includes("Clocks go back")
                && !CalendarService.warningFor(eve).includes("hour")
                && !CalendarService.warningFor(before) && !CalendarService.warningFor(change), "warning only on previous day")
            root.check(CalendarService.transitionFor(change).instant === Date.UTC(2026, 9, 25, 1), "UTC instant distinguishes repeated hour")
            root.check(!CalendarService.dayTooltip(eve).includes("2026-10-25")
                && !CalendarService.dayTooltip(eve).includes("Europe/Lisbon")
                && CalendarService.dayTooltip(eve).includes(Theme.rightIcon)
                && CalendarService.dayTooltip(eve).includes(Theme.fontFamilyIcons), "hover uses shared arrow without timezone")
            root.check(CalendarService.dayStyle(eve, false, true) === CalendarService.DayStyle.Invalid, "invalid precedes today")
            root.check(CalendarService.dayStyle(eve, true, true) === CalendarService.DayStyle.ClockChangeEve, "warning precedes today")
            root.check(CalendarService.dayStyle(before, true, true) === CalendarService.DayStyle.Today, "ordinary today highlight preserved")
            CalendarService._holidaysByYear[2026]["2026-10-24"] = "Banana"
            root.check(CalendarService.dayStyle(eve, true, false) === CalendarService.DayStyle.ClockChangeEve
                && CalendarService.dayTooltip(eve).includes("Banana"), "warning priority preserves holiday metadata")
            root.check(CalendarService.holidayFor(new Date(2026, 4, 22)) === "Dia de Leiria", "configured municipality")
            const ordinaryLink = decodeURIComponent(CalendarService.eventUrlFor(before))
            root.check(ordinaryLink.includes("dates=20261023/20261024")
                && !ordinaryLink.includes("&text=") && !ordinaryLink.includes("&details="),
                "ordinary date opens blank draft for clicked day")
            root.check(decodeURIComponent(CalendarService.eventUrlFor(new Date(2026, 11, 31)))
                .includes("dates=20261231/20270101"), "ordinary draft crosses year boundary")
            root.check(decodeURIComponent(CalendarService.eventUrlFor(new Date(2028, 1, 29)))
                .includes("dates=20280229/20280301"), "ordinary draft handles leap day")
            const holidayLink = CalendarService.eventUrlFor(new Date(2026, 11, 25))
            root.check(!holidayLink.includes("&text=") && !holidayLink.includes("&details="),
                "holiday draft also has no preset title or description")
            const link = decodeURIComponent(CalendarService.eventUrlFor(change))
            root.check(link.includes("20261024T170000Z/20261024T171500Z")
                && link.includes("ctz=Europe/Lisbon") && !link.includes("2026-10-25")
                && link.includes("details=Clocks go back: 02:00 → 01:00"),
                "autumn draft uses previous-day offset and omits transition date from description")
            root.check(CalendarService.eventUrlFor(change) === CalendarService.eventUrlFor(eve),
                "eve and transition share clock-change draft")
            root.check(decodeURIComponent(CalendarService.eventUrlFor(new Date(2027, 2, 28))).includes("20270327T180000Z/20270327T181500Z"), "future spring draft uses previous-day winter offset")
            const day = root.cells(month).find(cell => cell.dayNum === 24)
            root.check(day && day.color.toString() === Theme.warning.toString(), "rendered eve warning background")
            root.check(day && day.width === 26 && day.height === 26 && month.width === 225, "month geometry unchanged")
            root.check(year.width === 3 * 225 + 16, "annual grid geometry unchanged")
            const notice = CalendarService.clockChangeNotice
            month.displayYear = 2027; month.displayMonth = 2
            root.check(CalendarService.clockChangeNotice === notice, "browsing leaves live notice unchanged")
            root.check(!CalendarService.clockChangeNotice, "ordinary current date has no warning")
            root.step = 20
        }
    }
}
