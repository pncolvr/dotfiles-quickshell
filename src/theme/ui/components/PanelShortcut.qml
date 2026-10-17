pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "../" as UI

Shortcut {
    id: root
    required property Item owner
    property string action: ""
    property bool actionEnabled: true
    property string configuredSequence: UI.Keybinds.sequence(action)
    function ownsDialog(item: var): bool { return item.nativeDialogOpen === true }
    function blocksShortcuts(item: var): bool { return item.blocksPanelShortcuts === true }
    function blocked() {
        for (let item = owner; item; item = item.parent)
            if (ownsDialog(item)) return true
        for (let item = owner.Window.window?.activeFocusItem; item; item = item.parent)
            if (blocksShortcuts(item)) return true
        return false
    }
    sequence: configuredSequence
    autoRepeat: false
    enabled: !!configuredSequence && !!owner && owner.visible && owner.enabled
        && (owner.Window.window?.active ?? false) && actionEnabled && !blocked()
}
