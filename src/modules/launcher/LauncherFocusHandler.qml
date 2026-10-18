pragma ComponentBehavior: Bound
import QtQuick
import "../../ui" as UI
import "../../services"

UI.WindowFocusHandler {
    id: root
    property var picker: PickerService
    eagerActivation: true
    readonly property bool secretPrompt: picker.mode === PickerService.Mode.Secret
    focusSession: panel?.panel ?? panel
    ready: !!panel && (panel.focusReady ?? true)
    dismissOnOutside: !secretPrompt && (panel?.dismissOnOutside ?? true)
        && (!CaptureHandoffService.active || panel?.hideForCapture === true)
    onDismissRequested: picker.close("outside")
    Connections { target: root.picker; function onOpened() { root.requestFocus() } }
}
