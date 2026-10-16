pragma ComponentBehavior: Bound
import QtQuick
import "../../theme/ui" as UI
import "../../services"

UI.WindowFocusHandler {
    id: root
    property var picker: PickerService
    readonly property bool secretPrompt: picker.mode === PickerService.Mode.Secret
    focusSession: panel?.panel ?? panel
    ready: !!panel && (panel.focusReady ?? true)
    dismissOnOutside: !secretPrompt
    onDismissRequested: picker.close()
    Connections { target: root.picker; function onOpened() { root.requestFocus() } }
}
