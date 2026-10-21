pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/config"
import "../../src/modules/status"
import "../../src/modules/launcher"
import "../../src/services/status/TimeTracking.mjs" as Tracking
import "../../src/services/time/CalendarDates.mjs" as Dates
import "../../src/ui" as UI
import "../../src/theme"

WorkerScope {
    id: root
    readonly property string phase: Quickshell.env('STATUS_TEST_PHASE')
    property int ticks: 0
    property int step: 0
    property bool failed: false
    property int oldId: 0
    property real beforePause: 0
    Test.TestCase { id: events; when: false }
    function check(ok, message) {
        if (!ok) {
            failed = true;
            console.error('STATUS FAIL:', message);
        }
    }
    function find(item, name) {
        if (item.objectName === name)
            return item;
        for (const child of item.children ?? []) {
            const result = find(child, name);
            if (result)
                return result;
        }
        return null;
    }
    function modeAlert() {
        return AlertService.messages.find(message => message.id === 'status-mode');
    }
    function preview(name) {
        const folder = Quickshell.env('STATUS_PREVIEWS');
        if (folder) events.grabImage(window.contentItem).save(folder + '/' + name + '.png');
    }
    function finish() {
        if (!failed)
            console.log('PASS: native status ' + phase);
        timer.stop();
        Qt.quit();
    }
    QtObject {
        id: session
        property bool ready: true
        property bool active: true
        property bool locked: false
        property bool sleeping: false
        readonly property bool canTrack: ready && active && !locked && !sleeping
    }
    Component.onCompleted: StatusService.sessionState = session
    FloatingWindow {
        id: window
        color: Theme.tooltipBackground
        visible: true
        implicitWidth: 900
        implicitHeight: 900
        StatusTooltip {
            id: panel
            x: 10
            y: 10
        }
        EntryCategorySelector {
            id: category
            y: 850
            width: 200
        }
        UI.CalendarPeriodPicker {
            id: availabilityPicker
            visible: false
            width: 420
            kind: 'week'
            periods: ['2026-01-05','2026-03-02']
            selectedDate: new Date(2026,0,5)
            today: new Date(2026,2,17)
        }
    }
    Timer {
        id: timer
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (++root.ticks > 180 || root.failed) {
                root.check(false, 'timeout/failure in ' + root.phase + ' step ' + root.step);
                root.finish();
                return;
            }
            if (!StatusService.ready || !StatusService.initialized)
                return;
            if (root.phase === 'repository') {
                StatusService.pause();
                root.check(StatusRepository.claim('first'), 'claim tracking writer');
                const now = Date.now(), boundary = Tracking.cutoff(now, Config.workHistoryRetentionMonths);
                root.check(DbService.write(tx => {
                    tx.executeSql('DELETE FROM status_sessions');
                    tx.executeSql('INSERT INTO status_sessions(start_ms,end_ms,mode) VALUES(?,?,?)', [boundary - 2000, boundary - 1000, 'work']);
                    tx.executeSql('INSERT INTO status_sessions(start_ms,end_ms,mode) VALUES(?,?,?)', [boundary - 1000, boundary + 1000, 'personal']);
                }), 'seed retention intervals');
                root.check(StatusRepository.prune(now) && StatusRepository.sessions.length === 1, 'delete expired history');
                root.check(StatusRepository.sessions[0].start_ms === boundary && StatusRepository.sessions[0].end_ms === boundary + 1000, 'trim crossing interval without losing retained seconds');
                root.check(StatusRepository.transition('first', 'work', now) > 0, 'start session');
                const id = StatusRepository.sessions[StatusRepository.sessions.length - 1].id;
                root.check(StatusRepository.touch('first', id, now + 1000), 'durable checkpoint');
                root.check(StatusRepository.claim('second'), 'new process claims ownership');
                root.check(!StatusRepository.touch('first', id, now + 100000), 'stale writer cannot extend old session');
                root.check(StatusRepository.transition('first', 'personal', now + 2000) === null, 'stale transition rejected');
                root.check(StatusRepository.transition('second', 'personal', now + 2000) > 0, 'new process starts after gap');
                const next = StatusRepository.sessions[StatusRepository.sessions.length - 1];
                root.check(next.start_ms === now + 2000 && StatusRepository.sessions.find(row => row.id === id).end_ms === now + 1000, 'restart never fills gap');
                root.check(StatusRepository.transition('second', 'invalid', now + 3000) === null, 'invalid transition rolls back');
                root.check(StatusRepository.sessions[StatusRepository.sessions.length - 1].end_ms === now + 2000, 'failed transition did not close current session');
                StatusRepository.transition('second', '', now + 4000);
                PreferencesRepository.setValue('status.testCheckpoint', now + 4000);
                root.finish();
                return;
            }
            if (root.phase === 'disabled') {
                const entries = ['personal', 'work'].map(category => ({
                            id: category,
                            name: category,
                            category,
                            enabled: true,
                            path: '/synthetic/' + category,
                            workspaces: [],
                            url: 'https://example.test',
                            endpoint: 'example.test'
                        }));
                ProjectRepository.projects = entries;
                DirectoryRepository.directories = entries;
                WebappRepository.entries = entries;
                RemoteRepository.entries = entries;
                N8nRepository.entries = entries;
                root.check(ProjectService.availableProjects.length === 2 && DirectoryService.availableDirectories.length === 2, 'disabled Projects and Directories include both categories');
                root.check(WebappService.availableEntries.length === 2 && RemoteService.availableEntries.length === 2 && N8nService.availableEntries.length === 2, 'disabled managed pickers include both categories');
                root.check(!Config.workModeEnabled && !StatusService.enabled && !StatusService.tracking, 'disabled feature does not track');
                root.check(StatusService.includesCategory('work') && StatusService.includesCategory('personal'), 'disabled shows both categories');
                root.check(!category.visible && StatusService.filterHint('Ctrl+W') === '', 'category selector and filter hints hidden');
                root.check(PreferencesRepository.value('status.rules', {}).workDirectories.join('|') === '/synthetic/work|/synthetic/second|/synthetic/third', 'private rules retained while disabled');
                root.check(!StatusService.setStatus('work'), 'disabled mode rejects changes');
                root.check(!root.modeAlert(), 'disabled work mode posts no mode alerts');
                root.check(StatusRepository.sessions.some(row => row.end_ms === PreferencesRepository.value('status.testCheckpoint', 0)), 'history survives disabled restart');
                root.finish();
                return;
            }
            if (root.phase === 'restore') {
                if (!StatusService.tracking)
                    return;
                root.check(StatusService.status === 'work' && StatusService.source === 'manual', 'manual mode restored from SQLite');
                root.check(!root.modeAlert(), 'restoring saved mode after restart does not announce a change');
                root.check(StatusService.rules.workDirectories.join('|') === '/synthetic/work|/synthetic/second|/synthetic/third', 'detection rules restored');
                root.check(StatusRepository.sessions.some(row => row.end_ms === PreferencesRepository.value('status.testCheckpoint', 0)), 'old checkpoint unchanged after restart');
                root.check(StatusRepository.sessions[StatusRepository.sessions.length - 1].start_ms > PreferencesRepository.value('status.testCheckpoint', 0), 'new session starts after downtime');
                root.finish();
                return;
            }
            switch (root.step) {
            case 0:
                if (!StatusService.tracking)
                    return;
                root.check(!root.modeAlert(), 'startup establishes the mode silently');
                root.check(StatusService.setStatus('work'), 'set work manual mode');
                root.check(root.modeAlert()?.text === 'Work mode' && root.modeAlert().expiresAt > Date.now(), 'manual mode switch posts an expiring shared bar alert');
                const expiry = root.modeAlert().expiresAt;
                StatusService.setStatus('work');
                root.check(root.modeAlert().expiresAt === expiry, 'selecting the same mode does not repeat its alert');
                root.check(StatusService.status === 'work' && StatusService.source === 'manual', 'manual override takes effect');
                root.check(!StatusService.includesCategory('work') === false, 'work mode shows work entries');
                root.check(StatusService.saveRules({
                    workDirectories: ['/synthetic/work', '/synthetic/second'],
                    processes: ['synthetic-work']
                }), 'rules saved privately');
                root.oldId = StatusService.currentId;
                StatusService.heartbeat();
                root.beforePause = StatusRepository.sessions.find(row => row.id === root.oldId).end_ms;
                session.locked = true;
                root.check(!StatusService.tracking && !!StatusService.pauseReason, 'locking pauses recording immediately');
                break;
            case 1:
                root.check(!StatusService.tracking && StatusRepository.sessions.find(row => row.id === root.oldId).end_ms >= root.beforePause, 'locked interval remains closed');
                root.beforePause = StatusRepository.sessions.find(row => row.id === root.oldId).end_ms;
                break;
            case 2:
                root.check(StatusRepository.sessions.find(row => row.id === root.oldId).end_ms === root.beforePause, 'no work time recorded while locked');
                session.locked = false;
                root.check(StatusService.tracking && StatusService.currentId !== root.oldId, 'unlock starts a separate session');
                session.sleeping = true;
                root.check(!StatusService.tracking, 'suspend pauses');
                session.sleeping = false;
                root.check(StatusService.tracking, 'resume starts tracking');
                const before = StatusService.currentId;
                DbService.maintenance = true;
                StatusService.heartbeat();
                DbService.maintenance = false;
                root.check(StatusService.currentId === before && StatusService.tracking, 'backup maintenance does not stop tracking');
                session.active = false;
                root.check(!StatusService.tracking, 'inactive desktop pauses');
                session.active = true;
                StatusService.clear();
                break;
            case 3:
                {
                    if (StatusService.detectionMatches.length !== 1)
                        return;
                    timer.stop();
                    root.check(!root.find(availabilityPicker,'periodPickerToday').enabled,
                        'Today is disabled when current week has no records');
                    availabilityPicker.periods = ['2026-01-05','2026-03-02','2026-03-16'];
                    root.check(root.find(availabilityPicker,'periodPickerToday').enabled, 'Today enables when current week has records');
                    availabilityPicker.periods = [];
                    root.check(!root.find(availabilityPicker,'periodPickerToday').enabled && !availabilityPicker.adjacentPage(-1)
                        && !availabilityPicker.adjacentPage(1), 'empty data disables Today and calendar navigation');
                    root.check(StatusService.detectionMatches[0].name === 'synthetic-work', 'automatic detection uses private stored rules');
                    const unchangedAlert = root.modeAlert();
                    StatusService.clear();
                    root.check(root.modeAlert() === unchangedAlert, 'Reset with unchanged effective mode does not announce a change');
                    root.check(StatusService.source === 'automatic' && StatusService.status === 'work', 'Reset resumes automatic detected mode');
                    StatusService.setStatus('personal');
                    root.check(root.modeAlert()?.text === 'Personal mode', 'Personal mode uses the same alert slot');
                    root.check(!StatusService.includesCategory('work') && StatusService.includesCategory('personal'), 'enabled personal mode filters work entries');
                    StatusService.setStatus('work');
                    root.check(root.modeAlert()?.text === 'Work mode', 'returning to Work replaces the alert');
                    const manualAlert = root.modeAlert();
                    StatusService.automaticMode = 'personal';
                    root.check(root.modeAlert() === manualAlert, 'automatic evidence cannot announce a change hidden by a manual override');
                    StatusService.clear();
                    root.check(root.modeAlert()?.text === 'Personal mode', 'Reset announces a changed effective mode');
                    StatusService.automaticMode = 'work';
                    root.check(root.modeAlert()?.text === 'Work mode', 'automatic mode changes are announced');
                    root.check(AlertService.messages.filter(message => message.id === 'status-mode').length === 1, 'rapid mode changes replace rather than stack alerts');
                    StatusService.setStatus('work');
                    StatusService.heartbeat();
                    events.wait(30);
                    root.check(Dates.key(panel.historyDate) === StatusService.recordedPeriods.week.slice(-1)[0],
                        'missing previous week falls back to latest recorded week');
                    const previousWeek = Dates.shift(new Date(),'week',-1);
                    const olderMonth = Dates.shift(new Date(),'month',-3);
                    root.check(DbService.write(tx => {
                        for (const date of [previousWeek,olderMonth]) {
                            const start = new Date(date.getFullYear(),date.getMonth(),date.getDate(),9).getTime();
                            tx.executeSql('INSERT INTO status_sessions(start_ms,end_ms,mode) VALUES(?,?,?)',[start,start+3600000,'work']);
                        }
                    }) && StatusRepository.reload(), 'seed recorded periods with gaps');
                    panel.selectPeriod(previousWeek);
                    const tabs = root.find(panel, 'statusTimecardTabs') as QC.TabBar;
                    root.check(panel.period.days.length > 0 && panel.height > 0, 'Today report renders');
                    tabs.currentIndex = 1;
                    root.check(panel.period.days.length === 7, 'week includes all days');
                    root.check(tabs.count === 4, 'only Today, This week, History and Manage tabs remain');
                    tabs.currentIndex = 2;
                    events.wait(30);
                    root.check(panel.weekly && panel.period.days.length === 7
                        && Dates.key(panel.historyDate) === Dates.key(Dates.shift(new Date(),'week',-1)), 'History initially shows previous complete week');
                    const choose = root.find(panel, 'statusHistoryChoose');
                    events.mouseClick(choose, choose.width / 2, choose.height / 2);
                    events.wait(30);
                    const picker = root.find(panel, 'statusHistoryPicker') as UI.CalendarPeriodPicker;
                    root.check(picker.visible, 'period label opens calendar picker');
                    root.preview('history-week');
                    const week = root.find(picker, 'calendarWeek-' + Dates.key(panel.historyDate));
                    events.mouseClick(week, week.width / 2, week.height / 2);
                    root.check(!picker.visible && panel.period.days.length === 7, 'calendar row selects whole week and closes picker');
                    events.mouseClick(choose, choose.width / 2, choose.height / 2);
                    events.wait(30);
                    week.forceActiveFocus();
                    events.keyClick(Qt.Key_Return);
                    root.check(!picker.visible && choose.activeFocus, 'keyboard selects whole week and restores period-control focus');
                    root.find(panel,'statusHistoryKind').selected('month');
                    events.wait(30);
                    root.check(panel.period.days.length >= 28, 'month includes all days');
                    events.mouseClick(choose, choose.width / 2, choose.height / 2);
                    picker.displayYear = new Date().getFullYear();
                    events.wait(30);
                    root.preview('history-month');
                    const emptyMonth = Array.from({length:12},(_,index)=>index).find(index=>!StatusService.recordedPeriods.month.includes(
                        Dates.key(new Date(picker.displayYear,index,1))));
                    root.check(!root.find(picker,'periodPickerMonth-' + emptyMonth).enabled, 'calendar months without stored records cannot be selected');
                    const month = root.find(picker,'periodPickerMonth-' + new Date().getMonth());
                    events.mouseClick(month,month.width / 2,month.height / 2);
                    root.check(!picker.visible && !panel.weekly && !root.find(panel,'statusHistoryNext').enabled,
                        'current month selected, future navigation disabled');
                    root.find(panel,'statusHistoryPrevious').clicked();
                    root.check(Dates.key(panel.historyDate) === StatusService.recordedPeriods.month.slice(-2)[0],
                        'report arrow skips months without recorded data');
                    panel.selectPeriod(panel.earliest);
                    root.check(!root.find(panel,'statusHistoryPrevious').enabled, 'oldest recorded month is bounded');
                    const beforeInvalid = panel.historyDate.getTime();
                    panel.selectPeriod(Dates.shift(panel.historyDate,'month',-1));
                    root.check(panel.historyDate.getTime() === beforeInvalid, 'expired selections rejected');
                    events.mouseClick(choose,choose.width / 2,choose.height / 2);
                    events.wait(30);
                    const today = root.find(picker,'periodPickerToday');
                    events.mouseClick(today,today.width / 2,today.height / 2);
                    root.check(panel.historyKind === 'month' && Dates.key(panel.historyDate) === Dates.key(Dates.start(new Date(),'month'))
                        && !picker.visible, 'Today selects current month and preserves month range');
                    panel.selectPeriod(panel.earliest);
                    root.find(panel,'statusHistoryKind').selected('week');
                    root.check(panel.period.days.length === 7 && StatusService.recordedPeriods.week.includes(Dates.key(panel.historyDate)),
                        'switching from oldest partial month selects a retained week');
                    events.mouseClick(choose,choose.width / 2,choose.height / 2);
                    events.wait(30);
                    events.mouseClick(today,today.width / 2,today.height / 2);
                    root.check(panel.historyKind === 'week' && Dates.key(panel.historyDate) === Dates.key(Dates.start(new Date(),'week'))
                        && !picker.visible, 'Today selects current week and preserves week range');
                    tabs.currentIndex = 3;
                    root.check(panel.managing && root.find(panel, 'statusWorkDirectories').visible, 'Manage opens multiline work folders');
                    const field = root.find(panel, 'statusWorkFoldersList');
                    root.check(field.text === '/synthetic/work\n/synthetic/second', 'all saved work folders are shown one per line');
                    field.folderPicker.folderSelected('/synthetic/third');
                    field.folderPicker.folderSelected('/synthetic/third');
                    root.check(field.text === '/synthetic/work\n/synthetic/second\n/synthetic/third', 'picker appends a folder and ignores duplicates');
                    root.find(panel, 'statusRulesActions').submitted();
                    root.check(StatusService.rules.workDirectories.length === 3 && !panel.interactionPending, 'Save persists every folder and clears dirty state');
                    StatusService.pause();
                    PreferencesRepository.setValue('status.testCheckpoint', StatusRepository.sessions[StatusRepository.sessions.length - 1].end_ms);
                    root.finish();
                    return;
                }
            }
            root.step++;
        }
    }
}
