import QtQuick
import QtQml
import QtQuick.Templates as T

// Track input modality without clearing native/text-input focus.
TapHandler {
    id: root
    readonly property T.Control control: parent as T.Control
    property bool pointerUsed: false
    property bool keyboardUsed: false
    readonly property bool keyboardFocusVisible: !!control && control.activeFocus
        && (keyboardUsed || (!pointerUsed && control.visualFocus))
    target: null
    onPressedChanged: {
        if (pressed) { pointerUsed = true; keyboardUsed = false }
    }
    property Connections focusChanges: Connections {
        target: root.control
        function onActiveFocusChanged() { root.pointerUsed = false; root.keyboardUsed = false }
        function onFocusReasonChanged() {
            if ([Qt.TabFocusReason, Qt.BacktabFocusReason, Qt.ShortcutFocusReason].includes(root.control.focusReason)) {
                root.pointerUsed = false
                root.keyboardUsed = true
            }
        }
    }
    property Connections keyboardChanges: Connections {
        target: root.control ? root.control.Keys : null
        // Observe without accepting the event or replacing the control's handlers.
        function onShortcutOverride(event) { root.pointerUsed = false; root.keyboardUsed = true }
    }
}
