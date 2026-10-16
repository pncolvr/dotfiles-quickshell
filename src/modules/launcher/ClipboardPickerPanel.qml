pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"

PickerPanelBase {
    id: root
    searchPlaceholder: "Search clipboard"
    panelError: picker.error || ClipboardService.error
    minimumRowHeight: Theme.clipboardRowHeight
    readonly property bool imagesOnly: picker.itemCriteria.kind === "image"
    readonly property bool motionEnabled: UI.MotionPolicy.enabled
    property real imageProgress: 0
    property var exitPreviewEntry: null
    readonly property var previewEntry: imagesOnly && picker.filteredItems[picker.currentIndex]?.image
        ? picker.filteredItems[picker.currentIndex] : exitPreviewEntry
    readonly property bool transitioning: imageProgress !== (imagesOnly ? 1 : 0)
    readonly property bool sideBySide: availableContentWidth >= Theme.pickerWidth + 240
    implicitWidth: sideBySide ? Math.min(Theme.pickerWidth,availableContentWidth) + Math.max(0,availableContentWidth - Theme.pickerWidth) * imageProgress : Math.min(Theme.pickerWidth,availableContentWidth)
    implicitHeight: normalHeight + (Math.max(normalHeight,availableContentHeight) - normalHeight) * imageProgress
    fixedListWidth: sideBySide && imageProgress > 0 ? Theme.pickerWidth - Theme.tooltipPaddingHeight * 2 : 0
    previewOpacity: Math.max(0,Math.min(1,(imageProgress - 0.15) / 0.85))
    previewScale: 0.94 + 0.06 * previewOpacity + 0.03 * Math.sin(Math.PI * previewOpacity)
    stackedPreview: !sideBySide && imageProgress > 0
    previewComponent: imageProgress > 0 ? imagePreview : null
    function transition() {
        layoutMotion.stop()
        if (!picker.visible) { imageProgress = 0; return }
        if (motionEnabled) {
            layoutMotion.to = imagesOnly ? 1 : 0
            layoutMotion.restart()
        } else imageProgress = imagesOnly ? 1 : 0
    }
    onImagesOnlyChanged: { if (!imagesOnly) exitPreviewEntry = picker.filteredItems[picker.currentIndex] ?? null; transition() }
    onImageProgressChanged: if (imageProgress === 0) exitPreviewEntry = null
    onMotionEnabledChanged: transition()
    UI.MotionAnimation { id: layoutMotion; target: root; property: "imageProgress"; animationDuration: Theme.clipboardLayoutDuration; easing.type: Easing.OutCubic }
    Component {
        id: imagePreview
        ClipboardImagePreview {
            entries: root.picker.filteredItems
            entry: root.previewEntry
            searching: root.picker.searchPending
            decodeWidth: root.sideBySide ? Math.max(1,root.availableContentWidth - Theme.pickerWidth) : root.availableContentWidth
            decodeHeight: root.sideBySide ? root.availableContentHeight : root.availableContentHeight * 0.5
        }
    }
    Connections {
        target: root.picker
        function onVisibleChanged() { if (!root.picker.visible) { layoutMotion.stop(); root.imageProgress = 0; root.exitPreviewEntry = null } }
        function onSearchPendingChanged() { if (!root.picker.searchPending && root.imagesOnly && !root.picker.filteredItems[root.picker.currentIndex]?.image) root.exitPreviewEntry = null }
    }
    function setCriterion(name,value) {
        const criteria = Object.assign({},picker.itemCriteria)
        if (value === undefined) delete criteria[name]
        else criteria[name] = value
        picker.itemCriteria = criteria
        picker.currentIndex = 0
    }
    function toggleImagesOnly() { setCriterion("kind",imagesOnly ? undefined : "image") }
    readonly property bool pinnedOnly: picker.itemCriteria.pinned === true
    inlineFooter: imagesOnly && sideBySide
    footerHint: "Enter to paste · Ctrl+C to copy · Del to delete"
        + (imagesOnly && sideBySide ? " · " : "\n")
        + "Ctrl+P pin/unpin · Ctrl+Shift+P pinned only · Ctrl+Shift+I images"

    function sizeListForOpening() {
        const entries = picker.items.slice(0, Config.pickerMaxRows)
        openedListHeight = entries.length ? entries.reduce((height, entry) => height + (entry.image
            ? Theme.clipboardImagePreviewHeight + Theme.pickerRowPadding * 2 : Theme.clipboardRowHeight), 0)
            + (entries.length - 1) * Theme.controlSpacing : Theme.clipboardRowHeight
    }

    function deleteCurrentEntry() {
        if (picker.currentItem) ClipboardService.remove(picker.currentItem.id)
    }
    function toggleCurrentPin() {
        if (picker.currentItem) ClipboardService.togglePin(picker.currentItem.result)
    }
    function togglePinnedOnly() {
        setCriterion("pinned", pinnedOnly ? undefined : true)
        picker.currentIndex = 0
    }
    function acceptSelection(_modifiers) {
        picker.accept(false, false)
    }
    Keys.onDeletePressed: event => { root.deleteCurrentEntry(); event.accepted = true }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_I && event.modifiers === (Qt.ControlModifier | Qt.ShiftModifier)) { root.toggleImagesOnly(); event.accepted = true; return }
        if (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier) {
            root.picker.accept(false, true)
            event.accepted = true
            return
        }
        if (event.key !== Qt.Key_P) { event.accepted = false; return }
        if (event.modifiers === (Qt.ControlModifier | Qt.ShiftModifier)) root.togglePinnedOnly()
        else if (event.modifiers === Qt.ControlModifier) root.toggleCurrentPin()
        else { event.accepted = false; return }
        event.accepted = true
    }

    actionButtons: Component {
        Item {
            implicitWidth: toolbar.implicitWidth
            implicitHeight: Theme.controlHeight
            Row {
                id: toolbar
                anchors.right: parent.right
                spacing: Theme.controlSpacing
                UI.ActionButton { objectName: "clipboardImagesOnly"; glyph: Theme.imageIcon; foreground: root.imagesOnly ? Theme.accent : Theme.text; hint: "Images only (Ctrl+Shift+I)"; onClicked: root.toggleImagesOnly() }
                UI.ActionButton { objectName: "clipboardFuzzy"; glyph: Theme.searchIcon; foreground: root.picker.clipboardFuzzy ? Theme.accent : Theme.text; hint: "Use fuzzy search instead of indexed word/prefix search"; onClicked: root.picker.clipboardFuzzy = !root.picker.clipboardFuzzy }
                UI.ActionButton {
                    objectName: "clipboardPinnedOnly"
                    glyph: Theme.filterIcon
                    foreground: root.pinnedOnly ? Theme.accent : Theme.text
                    hint: root.pinnedOnly ? "Show all clipboard entries (Ctrl+Shift+P)" : "Show only pinned entries (Ctrl+Shift+P)"
                    onClicked: root.togglePinnedOnly()
                }
                UI.ActionButton {
                    objectName: "pinClipboardEntry"
                    glyph: Theme.filePinIcon
                    foreground: root.picker.currentItem?.pinned ? Theme.accent : Theme.inactive
                    hint: root.picker.currentItem?.pinned ? "Unpin entry (Ctrl+P)" : "Pin entry (Ctrl+P)"
                    enabled: !!root.picker.currentItem
                    onClicked: root.toggleCurrentPin()
                }
                UI.ActionButton {
                    glyph: Theme.deleteIcon
                    fillColor: Theme.urgent
                    hint: "Remove the highlighted entry from history (Delete)"
                    enabled: !!root.picker.currentItem
                    onClicked: root.deleteCurrentEntry()
                }
                UI.ActionButton {
                    objectName: "clearClipboardHistory"
                    glyph: Theme.clearIcon
                    fillColor: Theme.urgent
                    hint: "Remove unpinned clipboard entries; keep pinned entries"
                    onClicked: ClipboardService.clear()
                }
                UI.ActionButton {
                    glyph: Theme.pasteIcon
                    enabled: !!root.picker.currentItem && root.picker.destination.length > 0
                    fillColor: Theme.accent
                    hint: "Paste into the original window (Enter)"
                    onClicked: root.picker.accept(false, false)
                }
            }
        }
    }
}
