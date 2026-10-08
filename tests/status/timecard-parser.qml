import QtQuick
import Quickshell
import "../../src/modules/status"

Scope {
    id: root
    function check(condition, message) {
        if (!condition) { console.error("STATUS FAIL: " + message); Qt.quit(); throw new Error(message) }
    }
    Timer {
        interval: 1; running: true
        onTriggered: {
            const day = "2020-10-25\n  work 00:01:00\n  personal 00:02:30\n  blocks:\n"
                + "    start end category duration status\n"
                + "    09:00:00 09:01:00 work 00:01:00\n"
                + "    09:01:00 09:03:30 personal 00:02:30 ongoing\n"
            const report = Timecard.parse(day)
            root.check(report.work === 60 && report.personal === 150, "totals preserve native report seconds")
            root.check(report.days[0].blocks.length === 2 && report.days[0].blocks[1].ongoing, "session fields and ongoing marker")
            const week = Timecard.parse("2020-10-19 – 2020-10-25\n\n" + day)
            root.check(week.days.length === 7 && week.days[0].date === "2020-10-19" && week.days[6].date === "2020-10-25", "week fills inactive days across DST")
            root.check(week.work === 60 && week.personal === 150 && week.days[0].work === 0, "week totals include only recorded time")
            const empty = Timecard.parse("2020-10-26 – 2020-11-01\n\nNo completed time blocks found.")
            root.check(empty.days.length === 7 && empty.days[6].date === "2020-11-01" && empty.work === 0, "empty week across month boundary")
            const leapMonth = Timecard.parse("2020-02-01 – 2020-02-29\n\nNo completed time blocks found.")
            root.check(leapMonth.days.length === 29 && leapMonth.days[28].date === "2020-02-29", "leap month fills every day")
            const february = Timecard.parse("2021-02-01 – 2021-02-28\n\nNo completed time blocks found.")
            root.check(february.days.length === 28, "ordinary February has 28 days")
            const month = Timecard.parse("2020-10-01 – 2020-10-31\n\n" + day)
            root.check(month.days.length === 31 && month.days[0].date === "2020-10-01" && month.days[30].date === "2020-10-31", "month stays chronological across DST")
            root.check(month.work === 60 && month.personal === 150, "monthly totals retain native durations")
            root.check(Timecard.parse("").days.length === 0 && Timecard.parse("No completed time blocks found.").work === 0, "empty today")
            root.check(Timecard.duration(3660) === "1h 1m" && Timecard.duration(30) === "30s" && Timecard.duration(0) === "0m", "compact duration labels")
            root.check(Timecard.seconds("168:00:00") === 604800, "totals beyond 24 hours")
            console.log("PASS: timecard parser preserves totals, sessions, ongoing markers, empty days, DST and month boundaries")
            Qt.quit()
        }
    }
}
