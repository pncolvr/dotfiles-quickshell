pragma Singleton

import "../../i18n"
import QtQml
import Quickshell
import "../"
import "../../theme"

// Own the choices in Quickshell; the helper only executes an already chosen action.
Singleton {
    id: root
    readonly property var actions: [
        {title: Translations.text("power.actions.reboot"), glyph: Theme.powerRebootIcon, result: "Reboot"},
        {title: Translations.text("power.actions.lock"), glyph: Theme.powerLockIcon, result: "Lock"},
        {title: Translations.text("power.actions.logout"), glyph: Theme.powerLogoutIcon, result: "Logout"},
        {title: Translations.text("power.actions.shutdown"), glyph: Theme.powerShutdownIcon, result: "Shutdown"},
        {title: Translations.text("power.actions.bios"), glyph: Theme.powerBiosIcon, result: "Bios"}
    ]
    function open() {
        PickerService.promptMenu(Translations.text("common.actions.choose"), actions, picked => root.execute(picked[0].result), "grid")
    }
    function execute(action) {
        if (!actions.some(item => item.result === action)) return false
        StatusService.pause()
        Quickshell.execDetached(["bash", Quickshell.shellPath("src/services/launcher/providers/power.sh"), "--execute", action])
        return true
    }
}
