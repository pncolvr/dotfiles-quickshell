import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io

// Read-only lifecycle shared by activity-aware features. Unknown state pauses tracking.
Scope {
    id: root
    property bool enabled: false
    property bool ready: false
    property bool active: false
    property bool locked: true
    property bool sleeping: false
    property string sessionPath: ''
    property bool sessionKnown: false
    property bool lockKnown: false
    property bool sessionLocked: true
    property bool compositorLocked: true
    readonly property bool canTrack: enabled && ready && active && !locked && !sleeping && monitor.running
    function refresh() {
        if (!enabled || lookup.running || snapshot.running || lockState.running)
            return;
        if (!monitor.running)
            monitor.running = true;
        if (!sessionPath)
            lookup.running = true;
        else {
            snapshot.running = true;
            lockState.running = true;
        }
    }
    function settle() {
        locked = sessionLocked || compositorLocked;
        ready = sessionKnown && lockKnown;
    }
    function receive(line) {
        const sleep = line.match(/org\.freedesktop\.login1\.Manager\.PrepareFor(Sleep|Shutdown) \((true|false),?\)/);
        if (sleep) {
            sleeping = sleep[2] === 'true';
            if (!sleeping) {
                ready = false;
                refresh();
            }
            return;
        }
        if (sessionPath && line.startsWith(sessionPath + ':')) {
            if (/'LockedHint': <true>|'Active': <false>/.test(line))
                ready = false;
            refresh();
        }
    }
    onEnabledChanged: {
        if (enabled)
            refresh();
        else {
            lookup.running = false;
            snapshot.running = false;
            lockState.running = false;
            monitor.running = false;
            ready = false;
            sessionKnown = false;
            lockKnown = false;
            sessionPath = '';
        }
    }
    Timer {
        interval: 5000
        repeat: true
        running: root.enabled
        onTriggered: root.refresh()
    }
    Process {
        id: monitor
        command: ['gdbus', 'monitor', '--system', '--dest', 'org.freedesktop.login1']
        stdout: SplitParser {
            onRead: data => root.receive(data.trim())
        }
        stderr: StdioCollector {
            waitForEnd: true
        }
    }
    Process {
        id: lookup
        command: ['busctl', '--system', '--timeout=3', '--json=short', 'call', 'org.freedesktop.login1', '/org/freedesktop/login1', 'org.freedesktop.login1.Manager', 'GetSession', 's', Quickshell.env('XDG_SESSION_ID') || 'auto']
        stdout: StdioCollector {
            id: lookupOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            waitForEnd: true
        }
        // qmllint disable signal-handler-parameters
        onExited: (code, status) => {
            if (!root.enabled)
                return;
            try {
                if (code || status)
                    throw Error(Translations.text("session.errors.unavailable"));
                const path = JSON.parse(lookupOutput.text).data[0];
                if (typeof path !== 'string' || !path.startsWith('/org/freedesktop/login1/session/'))
                    throw Error(Translations.text("session.errors.invalidSession"));
                root.sessionPath = path;
                Qt.callLater(root.refresh);
            } catch (_) {
                root.ready = false;
            }
        }
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: snapshot
        command: ['busctl', '--system', '--timeout=3', '--json=short', 'call', 'org.freedesktop.login1', root.sessionPath, 'org.freedesktop.DBus.Properties', 'GetAll', 's', 'org.freedesktop.login1.Session']
        stdout: StdioCollector {
            id: sessionOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            waitForEnd: true
        }
        // qmllint disable signal-handler-parameters
        onExited: (code, status) => {
            if (!root.enabled)
                return;
            try {
                if (code || status)
                    throw Error(Translations.text("session.errors.unavailable"));
                const value = JSON.parse(sessionOutput.text).data[0];
                if (typeof value.Active?.data !== 'boolean' || typeof value.LockedHint?.data !== 'boolean')
                    throw Error(Translations.text("session.errors.invalidState"));
                root.active = value.Active.data && value.State?.data !== 'closing';
                root.sessionLocked = value.LockedHint.data;
                root.sessionKnown = true;
            } catch (_) {
                root.sessionKnown = false;
                root.active = false;
            }
            root.settle();
        }
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: lockState
        command: ['timeout', '3', 'hyprctl', '-j', 'locked']
        stdout: StdioCollector {
            id: lockOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            waitForEnd: true
        }
        // qmllint disable signal-handler-parameters
        onExited: (code, status) => {
            if (!root.enabled)
                return;
            try {
                if (code || status)
                    throw Error(Translations.text("session.errors.compositorUnavailable"));
                const value = JSON.parse(lockOutput.text).locked;
                if (typeof value !== 'boolean')
                    throw Error(Translations.text("session.errors.invalidLockState"));
                root.compositorLocked = value;
                root.lockKnown = true;
            } catch (_) {
                root.compositorLocked = true;
                root.lockKnown = false;
            }
            root.settle();
        }
        // qmllint enable signal-handler-parameters
    }
    Component.onCompleted: if (enabled)
        refresh()
}
