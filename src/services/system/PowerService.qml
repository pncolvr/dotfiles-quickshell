pragma Singleton

import QtQml
import Quickshell
import "../"
import "../../theme"

// Own the choices in Quickshell; the helper only executes an already chosen action.
Singleton {
    id: root
    readonly property var actions: [
        {title: "Reboot", glyph: Theme.powerRebootIcon, result: "Reboot"},
        {title: "Lock", glyph: Theme.powerLockIcon, result: "Lock"},
        {title: "Logout", glyph: Theme.powerLogoutIcon, result: "Logout"},
        {title: "Shutdown", glyph: Theme.powerShutdownIcon, result: "Shutdown"},
        {title: "Bios", glyph: Theme.powerBiosIcon, result: "Bios"}
    ]
    function open() {
        PickerService.promptMenu("Choose", actions, picked => root.execute(picked[0].result), "grid")
    }
    function execute(action) {
        if (!actions.some(item => item.result === action)) return false
        StatusService.pause()
        Quickshell.execDetached(["bash", Quickshell.shellPath("src/services/launcher/providers/power.sh"), "--execute", action])
        return true
    }
}
