pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"

// reload with: qs ipc call status reload

Singleton {
    id: root

    readonly property string status: _internal.status
    readonly property string source: _internal.source
    readonly property string summary: _internal.summary
    readonly property string todayTimecard: _internal.todayTimecard
    readonly property string currentWeekTimecard: _internal.currentWeekTimecard
    readonly property string lastWeekTimecard: _internal.lastWeekTimecard
    readonly property string currentMonthTimecard: _internal.currentMonthTimecard
    readonly property string lastMonthTimecard: _internal.lastMonthTimecard
    readonly property string timecardError: _internal.timecardError
    readonly property string timecardDate: _internal.timecardDate
    readonly property bool timecardLoading: reportProcess.running
    
    QtObject {
        id: _internal
        property string status: ""
        property string source: ""
        property string summary: ""
        property string todayTimecard: ""
        property string currentWeekTimecard: ""
        property string lastWeekTimecard: ""
        property string currentMonthTimecard: ""
        property string lastMonthTimecard: ""
        property string timecardError: ""
        property string timecardDate: ""
        property int panels: 0
        property bool includeWeeks: false
        property bool includeMonths: false
        property bool reportPending: false
    }
    function reload() {
        reloadTimer.restart()
    }
    function beginPanel() {
        if (_internal.panels === 0) {
            _internal.includeWeeks = false
            _internal.includeMonths = false
        }
        _internal.panels++
        refreshTimecard()
    }
    function endPanel() { _internal.panels = Math.max(0, _internal.panels - 1) }
    function showPeriod(index) {
        _internal.includeWeeks = index === 1 || index === 2
        _internal.includeMonths = index === 3 || index === 4
        if (index > 0) refreshTimecard()
    }
    function refreshTimecard() {
        if (reportProcess.running) { _internal.reportPending = true; return }
        _internal.reportPending = false
        reportProcess.command = Config.statusTimecardCommand(_internal.includeWeeks, _internal.includeMonths)
        reportProcess.running = true
    }
    Timer {
        interval: Config.statusTimecardRefreshInterval
        running: _internal.panels > 0
        repeat: true
        onTriggered: root.refreshTimecard()
    }

    Timer {
        id: reloadTimer
        interval: Config.debounceInterval
        repeat: false
        onTriggered: {
            checkProcess.running = true
            sourceProcess.running = true
        }
    }

    function toggle() {
        toggleProcess.running = true
    }

    function clear() {
        clearProcess.running = true
    }

    Process {
        id: checkProcess
        command: Config.statusManagerCheckCommand
        running: true
        stdout: StdioCollector { id: modeOutput; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0) _internal.status = modeOutput.text.trim()
            if (_internal.panels > 0) root.refreshTimecard()
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: sourceProcess
        command: Config.statusManagerSourceCommand
        running: true
        stdout: StdioCollector { id: sourceOutput; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0) _internal.source = sourceOutput.text.trim()
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: reportProcess
        stdout: StdioCollector { id: reportOutput; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            let report
            try { report = JSON.parse(reportOutput.text) } catch (_) { report = null }
            if (exitCode === 0 && exitStatus === 0 && typeof report?.summary === "string"
                && typeof report.today === "string" && typeof report.currentWeek === "string"
                && typeof report.lastWeek === "string" && typeof report.currentMonth === "string"
                && typeof report.lastMonth === "string" && typeof report.date === "string") {
                _internal.summary = report.summary.trim()
                _internal.todayTimecard = report.today.trim()
                if (report.weeksLoaded) {
                    _internal.currentWeekTimecard = report.currentWeek.trim()
                    _internal.lastWeekTimecard = report.lastWeek.trim()
                }
                if (report.monthsLoaded) {
                    _internal.currentMonthTimecard = report.currentMonth.trim()
                    _internal.lastMonthTimecard = report.lastMonth.trim()
                }
                _internal.timecardDate = report.date
                _internal.timecardError = ""
            } else _internal.timecardError = report?.error || "Could not read the timecard."
            if (_internal.reportPending && _internal.panels > 0) Qt.callLater(root.refreshTimecard)
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: toggleProcess
        command: Config.statusManagerToggleCommand
        onRunningChanged: if (!running) root.reload()
    }

    Process {
        id: clearProcess
        command: Config.statusManagerClearCommand
        onRunningChanged: if (!running) root.reload()
    }

    IpcHandler {
        target: "status"
        function reload(): void { root.reload() }
    }
}
