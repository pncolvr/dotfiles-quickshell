pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var messages: _internal.messages

    QtObject {
        id: _internal
        property var messages: []
    }

    function post(id, text) {
        const idx = _internal.messages.findIndex(m => m.id === id)
        if (idx >= 0) {
            const updated = [..._internal.messages]
            updated[idx] = { id, text }
            _internal.messages = updated
        } else {
            _internal.messages = [..._internal.messages, { id, text }]
        }
    }

    function dismiss(id) {
        _internal.messages = _internal.messages.filter(m => m.id !== id)
    }
}
