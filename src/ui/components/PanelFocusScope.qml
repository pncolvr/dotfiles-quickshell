pragma ComponentBehavior: Bound
import QtQuick
import ".." as UI

// Controls and child popups consume the configured cancel action first; only unhandled keys close us.
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
    Keys.onPressed: event => UI.Keybinds.handleCancel(event, () => root.dismissRequested())
}
