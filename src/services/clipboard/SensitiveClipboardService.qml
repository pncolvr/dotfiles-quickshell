pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property Process activeOwner: null
    signal released(var owner)

    // A positive lifetime keeps a foreground owner that can expire or be stopped.
    // Zero preserves wl-copy's usual detached lifetime, until replacement.
    // Callbacks receive true for success, false for failure, null for cancellation.
    function copy(value, lifetimeMs = 0, callback = null) {
        if (!value) return null
        stop(activeOwner)
        const owner = copyTask.createObject(root, {
            payload: value, lifetimeMs: Math.max(0, Math.floor(lifetimeMs)), callback
        }) as Process
        activeOwner = owner
        owner.running = true
        return owner
    }
    function stop(owner) {
        if (!Qt.isQtObject(owner) || owner.intentionalStop) return
        owner.intentionalStop = true
        owner.notify(null)
        owner.running = false
    }
    Component {
        id: copyTask
        Process {
            id: owner
            property string payload: ""
            property int lifetimeMs: 0
            property var callback: null
            property bool intentionalStop: false
            function notify(result) { if (callback) callback(result) }
            command: ["wl-copy", ...(lifetimeMs > 0 ? ["--foreground"] : []),
                "--sensitive", "--type", "text/plain;charset=utf-8"]
            stdinEnabled: true
            onStarted: {
                if (intentionalStop) { payload = ""; running = false; return }
                write(payload)
                payload = ""
                stdinEnabled = false
                if (lifetimeMs > 0) { expiry.start(); notify(true) }
            }
            stdout: SplitParser { onRead: _data => {} }
            stderr: SplitParser { onRead: _data => {} }
            property Timer expiryTimer: Timer {
                id: expiry
                interval: Math.max(1, owner.lifetimeMs)
                onTriggered: root.stop(owner)
            }
            // qmllint disable signal-handler-parameters
            onExited: (exitCode, exitStatus) => {
                const success = exitCode === 0 && exitStatus === 0
                if (!intentionalStop && (lifetimeMs === 0 || !success)) notify(success)
                callback = null
                payload = ""
                if (root.activeOwner === owner) root.activeOwner = null
                root.released(owner)
                owner.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
}
