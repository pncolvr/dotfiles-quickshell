pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
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
    readonly property bool secretPrompt: picker.mode === PickerService.Mode.Secret
    readonly property var nativeWindow: host.contentItem.Window.window
    property bool pointerPending: false
    property bool restoringDialogFocus: false
    function updateFocus() {
        if (!root.host.visible) { pointerPending = false; restoringDialogFocus = false; grab.active = false; return }
        if (panel?.nativeDialogOpen) { restoringDialogFocus = true; grab.active = false; return }
        if (secretPrompt) grab.active = false
        Qt.callLater(() => {
            if (!root.host.visible || !panel || panel.nativeDialogOpen) return
            panel.focusSearch()
            if (root.secretPrompt) {
                root.pointerPending = true
                root.nativeWindow?.update()
                return
            }
            if (!root.restoringDialogFocus || root.host.contentItem.Window.active) {
                root.restoringDialogFocus = false
                grab.active = true
            }
        })
    }
    Connections { target: root.host; function onVisibleChanged() { root.updateFocus() } }
    readonly property bool windowActive: host.contentItem.Window.active
    onWindowActiveChanged: if (windowActive && restoringDialogFocus && !panel?.nativeDialogOpen) updateFocus()
    Connections {
        target: root.nativeWindow
        function onFrameSwapped() {
            if (!root.pointerPending) return
            root.pointerPending = false
            if (root.host.visible && root.secretPrompt) BarModuleService.movePointer(root.panel?.panel)
        }
    }
    HyprlandFocusGrab {
        id: grab
        windows: [root.host]
        onCleared: if (root.host.visible && !root.secretPrompt && !root.panel?.nativeDialogOpen && !root.restoringDialogFocus) root.picker.close()
    }
    Connections {
        target: root.panel
        function onNativeDialogOpenChanged() { root.updateFocus() }
    }
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
        onLoaded: root.updateFocus()
    }
}
