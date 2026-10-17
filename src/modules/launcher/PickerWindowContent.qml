pragma ComponentBehavior: Bound
import QtQuick
import "../../services"
import "../../theme"
Item {
    id: root
    required property var host
    property var picker: PickerService
    property bool privateHost: false
    readonly property var panel: panelLoader.item
    readonly property real availableContentWidth: Math.max(0, (host.geometryScreen?.width || 800) - Theme.tooltipRadius * 2 - Theme.tooltipPaddingWidth * 2)
    readonly property real availableContentHeight: Math.max(0, (host.geometryScreen?.height || 1080) * 0.75 - host.shadowBottomPadding)
    readonly property real reservedHostHeight: (panel?.transitioning ? availableContentHeight : boundedContentHeight) + host.shadowBottomPadding
    readonly property real boundedContentWidth: Math.min(panel?.implicitWidth ?? Theme.pickerWidth,
        Math.max(0, (host.geometryScreen?.width || 800) - Theme.tooltipRadius * 2 - Theme.tooltipPaddingWidth * 2))
    property real measuredContentHeight
    // Loader geometry can change its child's implicit size while the native
    // host is applying a size. Publish that measurement after the binding turn.
    Binding on measuredContentHeight { value: root.panel?.implicitHeight ?? 0; delayed: true }
    readonly property real boundedContentHeight: Math.min(measuredContentHeight,
        Math.max(0, (host.geometryScreen?.height || 1080)
            * (panel?.floatingPreviewRequested ? Theme.pickerPreviewListHeightRatio : 0.75) - host.shadowBottomPadding))
    // A fitted preview can resize inside a stable placement footprint.
    readonly property real centeredContentX: (host.width - Math.min(panel?.placementWidth ?? boundedContentWidth, availableContentWidth)) / 2
    readonly property int keyboardFocusMode: focusHandler.keyboardFocusMode
    readonly property bool requestingKeyboardFocus: focusHandler.requestingKeyboardFocus
    readonly property bool secretPrompt: focusHandler.secretPrompt
    readonly property bool restoringDialogFocus: focusHandler.restoringDialogFocus
    readonly property var previewWindow: preview
    LauncherFocusHandler {
        id: focusHandler
        host: root.host; panel: root.panel; picker: root.picker
    }
    PickerPreviewWindow { id: preview; host: root.host; picker: root.picker; previewPanel: root.panel; privateWindow: root.privateHost }
    Component.onCompleted: ClipboardService.initialize()

    Loader {
        id: panelLoader
        active: root.enabled
        width: root.host.contentWidth
        height: root.host.contentHeight
        sourceComponent: PickerPanel {
            width: root.host.contentWidth
            height: root.host.contentHeight
            availableContentWidth: root.availableContentWidth
            availableContentHeight: root.availableContentHeight
            backgroundVisible: false
            picker: root.picker
        }
    }
}
