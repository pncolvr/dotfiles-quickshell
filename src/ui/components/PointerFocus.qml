import QtQuick

// A click on an already keyboard-focused control must also clear its focus ring.
TapHandler {
    target: null
    onPressedChanged: {
        if (pressed && parent.activeFocus) {
            parent.focus = false
            parent.forceActiveFocus(Qt.MouseFocusReason)
        }
    }
}
