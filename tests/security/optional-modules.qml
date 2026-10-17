pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../src/config"
import "../../src/services"
import "../../src/modules/system/totp"

Scope {
    id: root
    property var settings: Config
    property int step: 0
    property int ticks: 0
    property bool failed: false
    function check(ok, message) {
        if (!ok) { failed = true; console.error("OPTIONAL MODULES FAIL:", message) }
    }
    QtObject { id: origin; readonly property bool totpModule: true }
    QtObject { id: promptActions }
    Component { id: content; Item {} }
    FloatingWindow {
        id: host
        visible: true
        implicitWidth: 200
        implicitHeight: 100
        Totp { id: trigger; window: host }
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            root.ticks++
            if (root.ticks > 80) {
                root.check(false, "timed out at step " + root.step)
                Qt.quit()
                return
            }
            switch (root.step) {
            case 0:
                root.check(Config.totpEnabled && Config.vaultEnabled && trigger.visible,
                    "both modules preserve their enabled defaults")
                root.settings.totpEnabled = false
                root.settings.vaultEnabled = false
                root.step++
                break
            case 1:
                root.check(!trigger.visible && !BarModuleService.open("totp"),
                    "disabled TOTP hides its icon and rejects bar opening")
                TooltipService.show(0, content, origin, false)
                TotpService.start()
                TotpService.reload()
                root.check(!TotpService.active && TotpService.stopped && !TotpService.copy("fixture"),
                    "disabled TOTP cannot start or dispatch helper work")
                PickerService.promptSecret("Test prompt", "Synthetic", promptActions, _value => {})
                RbwService.open()
                root.check(!RbwService.visible && !RbwService.busy && PickerService.visible,
                    "disabled Vault cannot open or disturb independent secret prompts")
                root.check(!RbwService.request({action: "list"}), "disabled Vault rejects requests")
                PickerService.close()
                TooltipService.dismiss()
                root.settings.totpEnabled = true
                root.step++
                break
            case 2:
                root.check(trigger.visible && BarModuleService.open("totp"),
                    "TOTP can be enabled independently and opened through the bar")
                root.step++
                break
            case 3:
                if (!TotpService.ready) return
                root.check(TotpService.entries.count === 1 && !RbwService.enabled,
                    "enabled TOTP loads retained entries while Vault stays disabled")
                root.settings.totpEnabled = false
                root.settings.vaultEnabled = true
                RbwService.open()
                root.step++
                break
            case 4:
                if (RbwService.busy || !TotpService.stopped) return
                root.check(!TooltipService.visible && !TotpService.ready && TotpService.entries.count === 0,
                    "disabling open TOTP closes its panel, clears codes and stops its worker")
                root.check(RbwService.visible && RbwService.entries.length === 1,
                    "Vault opens independently with retained entries")
                root.settings.vaultEnabled = false
                root.step++
                break
            case 5:
                root.check(!RbwService.visible && RbwService.entries.length === 0,
                    "disabling open Vault closes and clears the manager")
                RbwService.open()
                root.check(!RbwService.visible && !RbwService.busy, "disabled Vault stays closed")
                root.settings.totpEnabled = true
                root.step++
                break
            case 6:
                BarModuleService.open("totp")
                root.step++
                break
            case 7:
                if (!TotpService.ready) return
                root.check(TotpService.entries.count === 1, "re-enabling TOTP preserves stored entries")
                TooltipService.dismiss()
                root.step++
                break
            case 8:
                if (!TotpService.stopped) return
                if (!root.failed) console.log("PASS: optional TOTP/Vault defaults, independent enablement, hidden entry points, stopped workers, retained entries and independent password prompts")
                Qt.quit()
            }
        }
    }
}
