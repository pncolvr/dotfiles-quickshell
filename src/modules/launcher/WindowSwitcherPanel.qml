pragma ComponentBehavior: Bound
import QtQuick
import "../../i18n"
import "../../theme/ui" as UI

PreviewPickerPanel {
    id: root
    previewKind: "windows"
    showThumbnails: false
    footerHint: Translations.text("picker.shortcuts.windowSwitch",[UI.Keybinds.sequence("preview")
        ? " · " + UI.Keybinds.describe("preview",Translations.text("common.actions.preview")) : ""])
    searchKeyHandler: (event, activate) => {
        if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && (event.modifiers & Qt.AltModifier)) {
            if (activate) root.picker.cycleWindowSwitch((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
            return true
        }
        return false
    }
}
