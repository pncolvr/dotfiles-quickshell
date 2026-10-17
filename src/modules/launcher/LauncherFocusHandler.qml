pragma ComponentBehavior: Bound
import QtQuick
import "../../theme/ui" as UI
import "../../services"

UI.WindowFocusHandler {
    id: root
    property var picker: PickerService
    eagerActivation: true
    readonly property bool secretPrompt: picker.mode === PickerService.Mode.Secret
    focusSession: panel?.panel ?? panel
    ready: !!panel && (panel.focusReady ?? true)
    dismissOnOutside: !secretPrompt && (!CaptureHandoffService.active || panel?.hideForCapture === true)
    onDismissRequested: picker.close(picker.independentClipboard ? "outside" : "cancelled")
    Connections { target: root.picker; function onOpened() { root.requestFocus() } }
}
