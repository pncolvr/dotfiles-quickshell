pragma ComponentBehavior: Bound
import QtQuick
import "../../services"
import "../../theme"
Item {
    id: root
    required property var host
    property var picker: PickerService
    readonly property var panel: panelLoader.item
    readonly property real availableContentWidth: Math.max(0, (host.geometryScreen?.width || 800) - Theme.tooltipRadius * 2 - Theme.tooltipPaddingWidth * 2)
    readonly property real availableContentHeight: Math.max(0, (host.geometryScreen?.height || 1080) * 0.75 - host.shadowBottomPadding)
    readonly property real reservedHostHeight: (panel?.transitioning ? availableContentHeight : boundedContentHeight) + host.shadowBottomPadding
    readonly property real boundedContentWidth: Math.min(panel?.implicitWidth ?? Theme.pickerWidth,
        Math.max(0, (host.geometryScreen?.width || 800) - Theme.tooltipRadius * 2 - Theme.tooltipPaddingWidth * 2))
    readonly property real boundedContentHeight: Math.min(panel?.implicitHeight ?? 0,
        Math.max(0, (host.geometryScreen?.height || 1080) * 0.75 - host.shadowBottomPadding))
    readonly property real centeredContentX: (host.width - boundedContentWidth) / 2
    readonly property bool secretPrompt: focusHandler.secretPrompt
    readonly property bool restoringDialogFocus: focusHandler.restoringDialogFocus
    LauncherFocusHandler { id: focusHandler; host: root.host; panel: root.panel; picker: root.picker }
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
