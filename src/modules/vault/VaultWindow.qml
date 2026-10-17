pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../bar"
import "../../services"
import "../../ui" as UI
import "../../theme"
PrivateTopPanelTooltip {
    id: root
    capturePanel: panel
    onCaptureHideRequested: RbwService.close()
    requestedScreen: Quickshell.screens.includes(RbwService.targetScreen) ? RbwService.targetScreen : Quickshell.screens[0] ?? null
    readonly property VaultPanel panel: loader.item as VaultPanel
    requestedVisible: RbwService.visible && !!requestedScreen
    contentWidth: Math.min(780, Math.max(0, (geometryScreen?.width ?? 800) - Theme.tooltipPaddingWidth * 2))
    contentHeight: Math.min(760, Math.max(0, (geometryScreen?.height ?? 1080) * 0.8 - shadowBottomPadding))
    contentX: (width - contentWidth) / 2
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: focusHandler.keyboardFocusMode
    UI.WindowFocusHandler {
        id: focusHandler
        host: root
        panel: root.panel
        // An unlock prompt belongs to the pending manager operation. Treat it
        // like a native child so closing it restores Search through the shared
        // handoff. Unrelated launchers only suspend the manager's focus.
        childDialogOpen: PickerService.visible && PickerService.mode === PickerService.Mode.Secret && RbwService.busy
        blocked: PickerService.visible && !childDialogOpen
        dismissOnOutside: false
    }
    Loader {
        id: loader
        active: root.visible
        width: root.contentWidth
        height: root.contentHeight
        sourceComponent: VaultPanel {}
    }
}
