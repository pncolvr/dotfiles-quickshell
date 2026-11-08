pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Dialogs as Dialogs
import "../../i18n"
import "../../ui/panels"
import "../../theme"
import "../../services"
import "../../config"

TopPanelTooltip {
    id: root
    capturePanel: panel
    onCaptureHideRequested: picker.close()
    property var picker: PickerService
    readonly property var panel: behavior.panel
    readonly property bool restoringDialogFocus: behavior.restoringDialogFocus
    readonly property bool windowActive: contentItem.Window.active
    readonly property Item previewItem: contentItem
    readonly property var floatingPreviewWindow: behavior.previewWindow
    property var clipboardSavingEntry: null
    readonly property bool nativeDialogOpen: saveClipboardDialog.visible || saveClipboardDialog.settling
    function saveClipboardEntry(entry) {
        if (!entry) return
        clipboardSavingEntry = entry
        const suffix = entry.kind === "image" ? entry.mime.split("/").pop() : "txt"
        const home = Quickshell.env("HOME").replace(/\/+$/, "")
        saveClipboardDialog.currentFile = "file://" + (home + "/clipboard." + suffix).split("/").map(encodeURIComponent).join("/")
        saveClipboardDialog.open()
        picker.close()
    }
    requestedScreen: Quickshell.screens.includes(picker.targetScreen) ? picker.targetScreen : Quickshell.screens[0] ?? null
    requestedVisible: picker.visible && picker.layout !== "expose" && !!picker.targetScreen
        && !picker.privateWindow
    contentWidth: behavior.boundedContentWidth
    contentHeight: behavior.boundedContentHeight
    continuousGeometry: panel?.transitioning ?? false
    centeredResize: true
    reservedContentHeight: behavior.reservedHostHeight - shadowBottomPadding
    contentX: behavior.centeredContentX
    backgroundOpacity: Theme.pickerBackgroundOpacity
    WlrLayershell.namespace: Config.pickerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: behavior.keyboardFocusMode

    Dialogs.FileDialog {
        id: saveClipboardDialog
        property bool settling: false
        title: Translations.text("clipboard.actions.saveTitle")
        fileMode: Dialogs.FileDialog.SaveFile
        defaultSuffix: root.clipboardSavingEntry?.kind === "image"
            ? root.clipboardSavingEntry.mime.split("/").pop() : "txt"
        function pathFor(url) { return decodeURIComponent(url.toString().replace(/^file:\/\/(?:localhost)?/, "")) }
        function finishSession() { if (!visible) settling = false }
        onVisibleChanged: {
            if (visible) settling = true
            else Qt.callLater(finishSession)
        }
        onAccepted: {
            const entry = root.clipboardSavingEntry
            root.clipboardSavingEntry = null
            if (entry) ClipboardService.saveEntry(entry, pathFor(selectedFile))
            finishSession()
        }
        onRejected: { root.clipboardSavingEntry = null; finishSession() }
        Connections {
            target: behavior.focusHandler
            function onWindowActiveChanged() {
                if (saveClipboardDialog.visible && behavior.focusHandler.windowActive)
                    behavior.focusHandler.restoringDialogFocus = true
            }
        }
    }

    PickerWindowContent { id: behavior; host: root; picker: root.picker; enabled: !root.picker.privateWindow; anchors.fill: parent }
}
