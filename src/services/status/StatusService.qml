pragma Singleton
import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../session"
import "../../config"
import "TimeTracking.mjs" as Tracking

Singleton {
    id: root
    readonly property bool enabled: Config.workModeEnabled
    readonly property bool ready: PreferencesRepository.ready && StatusRepository.ready
    readonly property string manualMode: PreferencesRepository.value('status.manual', '')
    readonly property var rules: PreferencesRepository.value('status.rules', {
        workDirectories: [],
        processes: []
    })
    readonly property string status: enabled ? manualMode || automaticMode : ''
    readonly property string source: {
        switch (true) {
        case !enabled:
            return '';
        case !!manualMode:
            return 'manual';
        default:
            return 'automatic';
        }
    }
    property var sessionState: desktopSession
    property bool actionPending: false
    readonly property bool paused: !enabled || actionPending || sessionState?.canTrack !== true
    readonly property string pauseReason: {
        switch (true) {
        case !enabled:
            return Translations.text("status.pause.disabled");
        case actionPending:
            return Translations.text("status.pause.pending");
        case !sessionState?.ready:
            return Translations.text("status.pause.waiting");
        case sessionState.sleeping:
            return Translations.text("status.pause.suspended");
        case sessionState.locked:
            return Translations.text("status.pause.locked");
        case !sessionState.active:
            return Translations.text("status.pause.inactive");
        default:
            return '';
        }
    }
    readonly property string token: Date.now() + '-' + Math.random().toString(36).slice(2)
    property string automaticMode: 'personal'
    property bool initialized: false
    property string announcedMode: ''
    property int currentId: 0
    property string trackedMode: ''
    property real checkpoint: 0
    readonly property bool tracking: currentId > 0
    property var report: ({})
    property int panels: 0
    property var detectionMatches: []
    property string detectionError: ''
    property bool detectionStale: false
    property bool detectionPending: false
    readonly property bool detectionEnabled: enabled && ready && !paused && !manualMode
    property bool detectionInFlight: false
    property int detectionRevision: 0
    property string rulesError: ''
    property string timecardError: ''
    readonly property bool detectionLoading: detectionEnabled && detectionInFlight
    readonly property bool timecardLoading: !ready
    readonly property bool changingStatus: !ready
    readonly property string summary: report.summary ?? ''
    readonly property string todayTimecard: report.today ?? ''
    readonly property string currentWeekTimecard: report.currentWeek ?? ''
    readonly property string lastWeekTimecard: report.lastWeek ?? ''
    readonly property string currentMonthTimecard: report.currentMonth ?? ''
    readonly property string lastMonthTimecard: report.lastMonth ?? ''
    readonly property string timecardDate: report.date ?? ''
    readonly property var recordedPeriods: Tracking.recordedPeriods(StatusRepository.sessions)
    property string wallpaperMode: ''
    property string appliedWallpaperMode: ''
    function includesCategory(category, showAll = false, workStatus = Config.pickerWorkStatus) {
        return !enabled || showAll || category !== 'work' || status === workStatus;
    }
    function filterHint(shortcut, showAll = false) {
        return enabled ? Translations.text(showAll ? "status.shortcuts.filterAll" : "status.shortcuts.filterMode",[shortcut]) : '';
    }
    function initialize() {
        if (!ready || initialized)
            return;
        if (!StatusRepository.prune() || !StatusRepository.claim(token)) {
            timecardError = StatusRepository.error;
            return;
        }
        initialized = true;
        // Restoration establishes the baseline; only later changes are announced.
        announcedMode = enabled ? status : '';
        reconcile();
        reload();
        refreshTimecard();
    }
    function announceModeChange() {
        const previous = announcedMode;
        announcedMode = enabled && ready && initialized ? status : '';
        if (!announcedMode) {
            AlertService.dismiss('status-mode');
            return;
        }
        if (!previous || previous === announcedMode)
            return;
        let message;
        switch (announcedMode) {
        case 'work':
            message = Translations.text("status.alerts.work");
            break;
        case 'personal':
            message = Translations.text("status.alerts.personal");
            break;
        default:
            return;
        }
        AlertService.post('status-mode', message, 'info', 3000);
    }
    function checkpointEnd(now = Date.now()) {
        return now < checkpoint || now - checkpoint > 30000 ? checkpoint : now;
    }
    function reconcile() {
        if (!initialized) {
            initialize();
            return;
        }
        const next = enabled && !paused ? status : '';
        if (next !== trackedMode) {
            const now = Date.now();
            const id = StatusRepository.transition(token, next, now, checkpointEnd(now));
            if (id === null) {
                timecardError = StatusRepository.error;
                return;
            }
            currentId = id;
            trackedMode = next;
            checkpoint = Date.now();
        }
        wallpaperMode = enabled ? status : 'personal';
        if (wallpaperMode !== appliedWallpaperMode)
            wallpaperDelay.restart();
        refreshTimecard();
    }
    function heartbeat(now = Date.now()) {
        if (DbService.maintenance)
            return;
        if (!tracking)
            return;
        if (now < checkpoint || now - checkpoint > 30000) {
            const id = StatusRepository.transition(token, trackedMode, now, checkpoint);
            if (id === null) {
                timecardError = StatusRepository.error;
                return;
            }
            currentId = id;
        }
        if (!StatusRepository.touch(token, currentId, now)) {
            timecardError = StatusRepository.error;
        } else {
            timecardError = '';
            checkpoint = now;
        }
        if (panels > 0)
            refreshTimecard();
    }
    function refreshTimecard() {
        if (ready)
            report = Tracking.reports(StatusRepository.sessions, Date.now(), currentId);
    }
    function periodReport(kind, date) {
        // Keep selected reports reactive to the same repository as live totals.
        return ready ? Tracking.periodReport(StatusRepository.sessions, kind, date, currentId) : '';
    }
    function beginPanel() {
        panels++;
        heartbeat();
        refreshTimecard();
        refreshDetection();
    }
    function endPanel() {
        panels = Math.max(0, panels - 1);
    }
    function showPeriod(_index) {
        heartbeat();
        refreshTimecard();
    }
    function reload() {
        if (detectionEnabled)
            detectionDelay.restart();
    }
    function refreshDetection() {
        if (!detectionEnabled)
            return;
        if (detectionInFlight) {
            detectionPending = true;
            return;
        }
        detectionPending = false;
        detector.revision = detectionRevision;
        detector.input = JSON.stringify(rules);
        detector.stdinEnabled = true;
        detectionInFlight = true;
        detector.running = true;
    }
    function saveRules(value) {
        try {
            const validated = Tracking.rules(value);
            if (!PreferencesRepository.setValue('status.rules', validated))
                throw Error(Translations.text("status.errors.saveRules"));
        } catch (exception) {
            rulesError = Translations.message(exception);
            return false;
        }
        rulesError = '';
        reload();
        return true;
    }
    function setStatus(mode) {
        return enabled && ready && ['work', 'personal'].includes(mode) && PreferencesRepository.setValue('status.manual', mode);
    }
    function toggleStatus(mode) {
        if (!enabled || !ready || !['work', 'personal'].includes(mode))
            return false;
        return manualMode === mode ? clear() : setStatus(mode);
    }
    function toggle() {
        return setStatus(status === 'work' ? 'personal' : 'work');
    }
    function clear() {
        if (enabled && ready) {
            if (!PreferencesRepository.setValue('status.manual', ''))
                return false;
            reload();
            return true;
        }
        return false;
    }
    function pause() {
        actionPending = true;
        actionDelay.restart();
    }
    Connections {
        target: DbService
        function onMaintenanceChanged() {
            if (!DbService.maintenance)
                root.reconcile();
        }
    }
    onReadyChanged: initialize()
    onEnabledChanged: {
        reconcile();
        announceModeChange();
    }
    onStatusChanged: {
        reconcile();
        announceModeChange();
    }
    onPausedChanged: reconcile()
    onDetectionEnabledChanged: {
        if (detectionEnabled) {
            reload();
        } else {
            detectionRevision++;
            detectionDelay.stop();
            detectionPending = false;
            detector.running = false;
        }
    }
    DesktopSessionState {
        id: desktopSession
        enabled: root.enabled === true && root.sessionState === desktopSession
    }
    Timer {
        id: actionDelay
        interval: 5000
        onTriggered: root.actionPending = false
    }
    Timer {
        interval: 10000
        running: root.tracking
        repeat: true
        onTriggered: root.heartbeat()
    }
    Timer {
        interval: 3600000
        running: root.initialized
        repeat: true
        onTriggered: {
            StatusRepository.prune();
            root.refreshTimecard();
        }
    }
    Timer {
        id: detectionDelay
        interval: 250
        onTriggered: root.refreshDetection()
    }
    Timer {
        id: wallpaperDelay
        interval: 100
        onTriggered: {
            root.appliedWallpaperMode = root.wallpaperMode;
            WallpaperService.restore(root.wallpaperMode);
        }
    }
    Process {
        id: detector
        property int revision: 0
        property string input: ''
        command: ['timeout', '10', 'bash', decodeURIComponent(Qt.resolvedUrl('detection.sh').toString().replace(/^file:\/\//, ''))]
        onStarted: {
            write(input);
            input = '';
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            id: detectionOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            waitForEnd: true
        }
        // qmllint disable signal-handler-parameters
        onExited: (code, status) => {
            root.detectionInFlight = false;
            if (!root.detectionEnabled)
                return;
            // A cancelled scan can finish after automatic mode is restored.
            if (revision !== root.detectionRevision) {
                root.reload();
                return;
            }
            let value;
            try {
                value = JSON.parse(detectionOutput.text);
                if (code || status || !Array.isArray(value.matches) || !Array.isArray(value.errors) || !value.matches.every(match => typeof match.name === 'string' && Array.isArray(match.methods) && Array.isArray(match.paths) && match.paths.every(path => typeof path === 'string')))
                    throw Error(Translations.text("status.errors.invalidDetection"));
            } catch (_) {
                root.detectionError = Translations.text("status.errors.readDetection");
                root.detectionStale = true;
                return;
            }
            root.detectionError = value.errors.join('\n');
            root.detectionStale = !!root.detectionError;
            if (!root.detectionError) {
                root.detectionMatches = value.matches;
                root.automaticMode = value.matches.length ? 'work' : 'personal';
            }
            if (root.detectionPending)
                Qt.callLater(root.refreshDetection);
        }
        // qmllint enable signal-handler-parameters
    }
    IpcHandler {
        target: 'status'
        function reload(): void {
            root.reload();
        }
        function pause(): void {
            root.pause();
        }
    }
    Component.onCompleted: initialize()
    Component.onDestruction: if (tracking)
        StatusRepository.touch(token, currentId, checkpointEnd())
}
