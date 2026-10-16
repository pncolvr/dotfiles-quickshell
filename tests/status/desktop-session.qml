import "../../src/services/session"
import QtQuick
import Quickshell

Scope {
    id: root

    property int step: 0
    property int ticks: 0
    property bool failed: false

    function check(ok, message) {
        if (!ok) {
            failed = true;
            console.error('STATUS FAIL:', message);
        }
    }

    DesktopSessionState {
        id: state

        enabled: true
    }

    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (++root.ticks > 200 || root.failed) {
                root.check(false, 'desktop session timeout');
                stop();
                Qt.quit();
                return;
            }
            switch (root.step) {
            case 0:
                if (!state.canTrack)
                    return;

                root.check(state.ready && state.active && !state.locked, 'read logind and compositor snapshot');
                state.receive('/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)');
                root.check(state.sleeping && !state.canTrack, 'sleep signal pauses immediately');
                state.receive('/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)');
                root.check(!state.ready && !state.canTrack, 'resume waits for fresh state');
                root.step++;
                break;
            case 1:
                if (!state.canTrack)
                    return;

                state.receive(state.sessionPath + ": org.freedesktop.DBus.Properties.PropertiesChanged ('org.freedesktop.login1.Session', {'LockedHint': <true>}, @as [])");
                root.check(!state.canTrack, 'lock signal pauses before asynchronous snapshot');
                root.step++;
                break;
            case 2:
                if (!state.canTrack)
                    return;

                state.enabled = false;
                root.check(!state.ready && !state.canTrack && !state.sessionPath, 'disabled monitor clears state and stops polling');
                if (!root.failed)
                    console.log('PASS: desktop session snapshots, lock/suspend signals and disabled lifecycle');

                stop();
                Qt.quit();
                break;
            }
        }
    }
}
