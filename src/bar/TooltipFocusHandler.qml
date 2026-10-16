pragma ComponentBehavior: Bound
import QtQuick
import "../theme/ui" as UI
import "../services"

UI.WindowFocusHandler {
    id: root
    required property var tooltipWindow
    host: tooltipWindow
    focusSession: TooltipService.source
    autoFocus: false
    passive: true
    // The trigger remains clickable while interacting with its panel.
    interactionWindows: [host, TooltipService.source?.tooltipWindow].filter(window => !!window)
    // Hover never activates a focus grab. Explicit field/control interaction can.
    dismissOnOutside: !TooltipService.pinned
    readonly property var editor: nativeWindow?.activeFocusItem
    readonly property bool protectingEditor: windowActive && editor?.retainPanelWhileEditing === true
    readonly property bool blocksReplacement: nativeDialogOpen || panel?.interactionPending === true || protectingEditor
    readonly property bool holding: hostRequestedVisible && ready && (blocksReplacement
        || (windowActive && TooltipService.keyboardActive))
    function syncInteraction() { TooltipService.setInteraction(root, holding, blocksReplacement) }
    onHoldingChanged: syncInteraction()
    onBlocksReplacementChanged: syncInteraction()
    Component.onDestruction: TooltipService.setInteraction(root, false)
    onDismissRequested: TooltipService.dismiss()
    Connections {
        target: TooltipService
        function onFocusRequested() { if (root.hostRequestedVisible) root.requestFocus() }
    }
}
