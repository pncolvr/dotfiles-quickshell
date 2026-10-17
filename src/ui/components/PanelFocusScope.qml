pragma ComponentBehavior: Bound
import QtQuick

// Controls and child popups consume Escape first; only unhandled keys close us.
FocusScope {
    id: root
    focus: true
    property var panel: null
    readonly property bool nativeDialogOpen: panel?.nativeDialogOpen === true
    readonly property bool interactionPending: panel?.interactionPending === true
    signal dismissRequested()
    function focusSearch() {
        if (panel && typeof panel.focusSearch === "function") panel.focusSearch()
        else root.forceActiveFocus()
    }
    Keys.onEscapePressed: root.dismissRequested()
}
