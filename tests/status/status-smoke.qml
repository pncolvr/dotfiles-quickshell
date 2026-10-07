pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/modules/status"
import "../../src/services"
import "../../src/theme"

Scope {
    id: root
    property int step: 0
    property int ticks: 0
    property bool failed: false
    function check(ok, message) {
        if (ok) return
        failed = true
        console.error("STATUS FAIL:", message)
    }
    function find(name) { return mouse.findChild(panel, name) }
    QtObject {
        id: backend
        property string status: "personal"
        property string source: "automatic"
        property string summary: "work     00:01:00\npersonal 00:01:00"
        property string todayTimecard: "Today's detailed timecard"
        property string currentWeekTimecard: Array.from({length: 200}, (_, index) => "Block " + index + "  09:00:00  18:00:00 work       09:00:00").join("\n")
        property string lastWeekTimecard: "Last week's detailed timecard"
        property string timecardError: ""
        property string timecardDate: Qt.formatDateTime(new Date(), "yyyy-MM-dd")
        property bool timecardLoading: false
        property int panels: 0
        property int refreshes: 0
        property bool weeksShown: false
        function beginPanel() { panels++ }
        function endPanel() { panels-- }
        function showWeeks(show) { weeksShown = show }
        function refreshTimecard() { refreshes++ }
    }
    Test.TestCase { id: mouse; when: false }
    FloatingWindow {
        id: testWindow
        visible: true
        implicitWidth: 800
        implicitHeight: 800
        color: Theme.background
        Status { id: trigger; visible: false }
        StatusTooltip { id: panel; statusService: backend; x: 20; y: 20 }
        Component.onCompleted: {
            const realPanel = trigger.tooltip.createObject(contentItem, {visible: false})
            root.check(realPanel !== null, "bar status import resolves its timecard tooltip")
        }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (++root.ticks > 100) { root.check(false, "status test timeout at step " + root.step); Qt.quit(); return }
            if (StatusService.timecardLoading) return
            const tabs = root.find("statusTimecardTabs") as QC.TabBar
            const report = root.find("statusTimecardReport") as Text
            const view = root.find("statusTimecardView") as Flickable
            if (root.step === 0) {
                if (!StatusService.summary || !StatusService.status || !StatusService.source) return
                root.check(StatusService.status === "personal" && StatusService.source === "automatic", "mode/source support output without a trailing newline")
                root.check(StatusService.summary === backend.summary && StatusService.todayTimecard.includes("blocks:"), "real service reads Conky summary and zsh timecard")
                backend.todayTimecard = StatusService.todayTimecard
                root.check(StatusService.currentWeekTimecard === "" && StatusService.lastWeekTimecard === "", "weeks are loaded only when requested")
                root.check(backend.panels === 1 && tabs.currentIndex === 0, "tooltip defaults to today's detailed timecard")
                root.check((root.find("statusSummary") as Text).text === backend.summary && report.text === backend.todayTimecard,
                    "summary and full timecard are visible together")
                root.check(tabs.count === 3, "Today, Current week, and Last week tabs replace All time")
                const currentWeek = tabs.itemAt(1)
                mouse.mouseClick(currentWeek, currentWeek.width / 2, currentWeek.height / 2)
                StatusService.showWeeks(true)
            } else if (root.step === 1) {
                root.check(backend.weeksShown && report.text === backend.currentWeekTimecard, "Current week displays its timecard")
                root.check(panel.height <= panel.maxPanelHeight && view.contentHeight > view.height, "long timecards stay bounded and scroll")
                root.check(StatusService.currentWeekTimecard.includes(StatusService.timecardDate)
                    && StatusService.lastWeekTimecard.length > 0, "real service reads both weekly reports")
                const lastWeek = tabs.itemAt(2)
                mouse.mouseClick(lastWeek, lastWeek.width / 2, lastWeek.height / 2)
            } else if (root.step === 2) {
                root.check(backend.weeksShown && report.text === backend.lastWeekTimecard, "Last week displays its timecard")
                const screenshot = Quickshell.env("STATUS_TEST_SCREENSHOT")
                if (screenshot) {
                    backend.lastWeekTimecard = StatusService.lastWeekTimecard
                    panel.grabToImage(result => result.saveToFile(screenshot))
                }
                const refresh = root.find("refreshTimecard") as QC.Button
                mouse.mouseClick(refresh, refresh.width / 2, refresh.height / 2)
                root.check(backend.refreshes === 1, "refresh button reloads the reports")
                StatusService.toggle()
            } else if (root.step === 3) {
                if (StatusService.status !== "work" || StatusService.source !== "manual") return
                StatusService.clear()
            } else if (root.step === 4) {
                if (StatusService.status !== "personal" || StatusService.source !== "automatic") return
                backend.timecardError = "The configured timetable file is unavailable."
                backend.summary = ""
                backend.todayTimecard = ""
                const today = tabs.itemAt(0)
                mouse.mouseClick(today, today.width / 2, today.height / 2)
            } else if (root.step === 5) {
                const feedback = root.find("statusTimecardFeedback") as Text
                root.check(feedback.visible && feedback.text === backend.timecardError, "report failures are visible")
                root.check(panel.height <= panel.maxPanelHeight, "error panel remains bounded")
                root.check(!backend.weeksShown && tabs.currentIndex === 0, "Today can be selected again")
                console.log(root.failed ? "STATUS FAIL: panel" : "PASS: status timecard, brief/full reports, current/last week tabs, scrolling, refresh, mode actions and errors")
                Qt.quit()
            }
            root.step++
        }
    }
}
