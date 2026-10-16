pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var messages: _internal.messages

    QtObject {
        id: _internal
        property var messages: []
    }

    function post(id, text, severity = "error", duration = 0, captureBlocking = false) {
        if (!id.trim() || !text.trim() || !["info", "success", "warning", "error"].includes(severity)
            || !Number.isFinite(duration) || duration < 0) return false
        const message = {id, text, severity, captureBlocking, expiresAt: duration > 0 ? Date.now() + duration : 0}
        const idx = _internal.messages.findIndex(m => m.id === id)
        if (idx >= 0) {
            const updated = [..._internal.messages]
            updated[idx] = message
            _internal.messages = updated
        } else {
            _internal.messages = [..._internal.messages, message]
        }
        expiry.restart()
        return true
    }

    function dismiss(id) {
        _internal.messages = _internal.messages.filter(m => m.id !== id)
        expiry.restart()
    }
    Timer {
        id: expiry
        interval: {
            const deadlines = root.messages.filter(message => message.expiresAt > 0).map(message => message.expiresAt)
            return deadlines.length ? Math.max(1, Math.ceil(Math.min(...deadlines) - Date.now())) : 1
        }
        onTriggered: {
            const now = Date.now()
            _internal.messages = root.messages.filter(message => !message.expiresAt || message.expiresAt > now)
            if (root.messages.some(message => message.expiresAt > 0)) restart()
        }
    }
    IpcHandler {
        target: "alerts"
        function post(id: string, text: string, severity: string, duration: int): bool {
            return root.post(id, text, severity, duration)
        }
        function postCapture(id: string, text: string, severity: string, duration: int): bool {
            return root.post(id, text, severity, duration, true)
        }
        function dismiss(id: string): void { root.dismiss(id) }
    }
}
