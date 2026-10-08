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
    function check(ok, message) { if (!ok) { failed = true; console.error("STATUS FAIL:", message) } }
    function find(name) { return mouse.findChild(panel, name) }
    function clickTab(index) {
        (root.find("statusTimecardTabs") as QC.TabBar).currentIndex = index
    }
    QtObject {
        id: backend
        property string status: "personal"
        property string source: "automatic"
        property string todayTimecard: ""
        property string currentWeekTimecard: ""
        property string lastWeekTimecard: ""
        property string currentMonthTimecard: ""
        property string lastMonthTimecard: ""
        property string timecardError: ""
        property string timecardDate: Qt.formatDateTime(new Date(), "yyyy-MM-dd")
        property bool timecardLoading: false
        property int panels: 0
        property int refreshes: 0
        property bool weeksShown: false
        property bool monthsShown: false
        property int toggles: 0
        property int resets: 0
        function beginPanel() { panels++ }
        function endPanel() { panels-- }
        function showPeriod(index) { weeksShown = index === 1 || index === 2; monthsShown = index === 3 || index === 4 }
        function toggle() { toggles++ }
        function clear() { resets++ }
        function reload() { refreshes++ }
    }
    Test.TestCase { id: mouse; when: false }
    FloatingWindow {
        visible: true
        implicitWidth: 800
        implicitHeight: 800
        color: Theme.background
        Status { id: trigger; x: 650; y: 20 }
        StatusTooltip { id: panel; statusService: backend; x: 20; y: 20 }
        Component.onCompleted: {
            const realPanel = trigger.tooltip.createObject(contentItem, {visible: false})
            root.check(realPanel !== null, "bar status import resolves its tooltip")
        }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (++root.ticks > 100) { root.check(false, "timeout at step " + root.step); Qt.quit(); return }
            if (StatusService.timecardLoading) return
            const tabs = root.find("statusTimecardTabs") as QC.TabBar
            const view = root.find("statusTimecardView") as Flickable
            if (root.step === 0) {
                if (!StatusService.summary || !StatusService.status || !StatusService.source) return
                root.check(StatusService.status === "personal" && StatusService.source === "automatic", "mode and detection source")
                backend.todayTimecard = StatusService.todayTimecard
                root.check(panel.period.work === 60 && panel.period.personal === 60, "today uses native totals")
                root.check((root.find("statusWorkTotal") as Text).text === "1m" && (root.find("statusPersonalTotal") as Text).text === "1m", "compact work and personal totals")
                root.check(backend.panels === 1 && tabs.currentIndex === 0 && tabs.count === 5, "opens on Today with five periods")
                root.check(StatusService.currentWeekTimecard === "" && StatusService.lastWeekTimecard === "", "weeks are read on demand")
                root.check(panel.expandedDay === "" && root.find("statusSession") === null, "Today hides session details initially")
                const today = root.find("statusDay_" + backend.timecardDate) as MouseArea
                mouse.mouseClick(today, today.width / 2, today.height / 2)
                root.check(panel.expandedDay === backend.timecardDate, "Today sessions can be expanded")
                root.clickTab(1)
                root.check(panel.expandedDay === "", "changing period collapses Today")
                StatusService.showPeriod(1)
            } else if (root.step === 1) {
                if (!StatusService.currentWeekTimecard) return
                backend.currentWeekTimecard = StatusService.currentWeekTimecard
                backend.lastWeekTimecard = StatusService.lastWeekTimecard
                root.check(backend.weeksShown && panel.period.days.length === 7, "weekly rows include all seven days")
                const expected = new Date().getDay() === 1 ? 60 : 120
                root.check(panel.period.work === expected && panel.period.personal === expected, "totals follow the selected week")
                const day = root.find("statusDay_" + backend.timecardDate) as MouseArea
                mouse.mouseClick(day, day.width / 2, day.height / 2)
                root.check(panel.expandedDay === backend.timecardDate, "clicking a day expands its sessions")
                backend.currentWeekTimecard = StatusService.currentWeekTimecard.split("\n")[0] + "\n" + backend.timecardDate
                    + "\n  work 03:20:00\n  personal 00:00:00\n  blocks:\n"
                    + Array.from({length: 200}, () => "    09:00:00 09:01:00 work 00:01:00").join("\n")
            } else if (root.step === 2) {
                root.check(panel.height <= panel.maxPanelHeight && view.contentHeight > view.height, "expanded sessions stay bounded and scroll")
                view.contentY = view.contentHeight - view.height
            } else if (root.step === 3) {
                root.check(view.atYEnd && view.contentWidth === view.width, "last session is reachable without horizontal scrolling")
                const screenshot = Quickshell.env("STATUS_TEST_SCREENSHOT")
                if (screenshot) panel.grabToImage(result => result.saveToFile(screenshot))
                root.clickTab(2)
                root.check(panel.expandedDay === "" && panel.period.days.length === 7, "changing week closes expanded sessions")
                root.check(panel.period.work === (new Date().getDay() === 1 ? 60 : 0), "last week has independent totals")
                const refresh = root.find("refreshTimecard") as QC.Button
                mouse.mouseClick(refresh, refresh.width / 2, refresh.height / 2)
                root.check(backend.refreshes === 1, "refresh requests a mode recheck")
                const toggle = root.find("toggleStatusMode") as QC.Button
                root.check(toggle.x > refresh.x + refresh.width, "mode toggle follows Reload")
                mouse.mouseClick(toggle, toggle.width / 2, toggle.height / 2)
                root.check(backend.toggles === 1, "tooltip button toggles the mode")
                StatusService.reload()
                StatusService.toggle()
            } else if (root.step === 4) {
                if (StatusService.status !== "work" || StatusService.source !== "manual") return
                mouse.mouseClick(trigger, trigger.width / 2, trigger.height / 2, Qt.RightButton)
                mouse.mouseClick(trigger, trigger.width / 2, trigger.height / 2, Qt.LeftButton)
                root.check(TooltipService.pinned && TooltipService.source === trigger, "left-click pins the status tooltip")
                mouse.mouseClick(trigger, trigger.width / 2, trigger.height / 2, Qt.LeftButton)
                root.check(!TooltipService.pinned, "second click unpins the status tooltip")
            } else if (root.step === 5) {
                root.check(StatusService.status === "work" && StatusService.source === "manual", "bar clicks leave the manual mode unchanged")
                backend.source = "manual"
                const reset = root.find("resetStatusMode") as QC.Button
                const toggle = root.find("toggleStatusMode") as QC.Button
                root.check(reset.x > toggle.x + toggle.width, "Reset follows the mode toggle")
                mouse.mouseClick(reset, reset.width / 2, reset.height / 2)
                root.check(backend.resets === 1, "Reset restores automatic detection")
                StatusService.clear()
            } else if (root.step === 6) {
                if (StatusService.status !== "personal" || StatusService.source !== "automatic") return
                root.clickTab(3)
                StatusService.showPeriod(3)
            } else if (root.step === 7) {
                if (!StatusService.currentMonthTimecard) return
                backend.currentMonthTimecard = StatusService.currentMonthTimecard
                backend.lastMonthTimecard = StatusService.lastMonthTimecard
                const now = new Date()
                const days = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
                root.check(backend.monthsShown && !backend.weeksShown && panel.period.days.length === days, "This month shows every calendar day")
                root.check(panel.period.work === (now.getDate() === 1 ? 60 : 120), "current month has independent totals")
                root.check(panel.period.days[0].date.endsWith("-01") && panel.period.days[days - 1].date.endsWith("-" + days), "date order stays chronological")
            } else if (root.step === 8) {
                root.check(panel.height <= panel.maxPanelHeight && view.contentHeight > view.height, "monthly rows stay bounded and scroll")
                root.clickTab(4)
                const now = new Date()
                const previousDays = new Date(now.getFullYear(), now.getMonth(), 0).getDate()
                root.check(panel.period.days.length === previousDays && panel.period.work === (now.getDate() === 1 ? 60 : 0), "Last month uses its own calendar boundaries and totals")
                backend.timecardError = "The configured timetable file is unavailable."
                backend.todayTimecard = ""
                root.clickTab(0)
            } else if (root.step === 9) {
                const feedback = root.find("statusTimecardFeedback") as Text
                root.check(feedback.visible && feedback.text === backend.timecardError, "report failures remain visible")
                root.check(panel.height <= panel.maxPanelHeight && !backend.weeksShown && !backend.monthsShown, "error view stays bounded and returns to Today")
                console.log(root.failed ? "STATUS FAIL: panel" : "PASS: status timecard totals, period tabs, daily expansion, scrolling, refresh, mode actions and errors")
                Qt.quit()
                return
            }
            root.step++
        }
    }
}
