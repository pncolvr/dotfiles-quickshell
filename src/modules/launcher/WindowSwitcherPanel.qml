pragma ComponentBehavior: Bound
import QtQuick

PreviewPickerPanel {
    id: root
    previewKind: "windows"
    showThumbnails: false
    hintPanel: "windows"
    hintActions: ["preview", "search", "windows.previous"]
    hintOverrides: ({"windows.previous": {sequence: "Alt+Shift+Tab"}})
    searchKeyHandler: (event, activate) => {
        if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && (event.modifiers & Qt.AltModifier)) {
            if (activate) root.picker.cycleWindowSwitch((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
            return true
        }
        return false
    }
}
