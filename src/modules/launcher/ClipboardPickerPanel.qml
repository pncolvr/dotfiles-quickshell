pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"

PickerPanelBase {
    id: root
    searchPlaceholder: Translations.text("clipboard.search.placeholder")
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
    footerHint: Translations.text("clipboard.shortcuts.primary")
        + (imagesOnly && sideBySide ? " · " : "\n")
        + [UI.Keybinds.describe("clipboard.pin",Translations.text(root.picker.currentItem?.pinned ? "clipboard.actions.unpinHint" : "clipboard.actions.pinHint")),
            UI.Keybinds.describe("clipboard.pinnedOnly",Translations.text("clipboard.filter.pinnedHint")),
            UI.Keybinds.describe("preview",Translations.text("clipboard.filter.images"))].filter(Boolean).join(" · ")

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
        if (event.matches(StandardKey.Copy)) root.picker.accept(false, true)
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
                UI.ActionButton { objectName: "clipboardImagesOnly"; keyAction: "preview"; glyph: Theme.imageIcon; foreground: root.imagesOnly ? Theme.accent : Theme.text; hint: Translations.text("clipboard.filter.images"); onClicked: root.toggleImagesOnly() }
                UI.ActionButton { objectName: "clipboardFuzzy"; glyph: Theme.searchIcon; foreground: root.picker.clipboardFuzzy ? Theme.accent : Theme.text; hint: Translations.text("clipboard.search.fuzzyHint"); onClicked: root.picker.clipboardFuzzy = !root.picker.clipboardFuzzy }
                UI.ActionButton {
                    objectName: "clipboardPinnedOnly"
                    keyAction: "clipboard.pinnedOnly"
                    glyph: Theme.filterIcon
                    foreground: root.pinnedOnly ? Theme.accent : Theme.text
                    hint: Translations.text(root.pinnedOnly ? "clipboard.filter.showAllHint" : "clipboard.filter.pinnedHint")
                    onClicked: root.togglePinnedOnly()
                }
                UI.ActionButton {
                    objectName: "pinClipboardEntry"
                    keyAction: "clipboard.pin"
                    glyph: Theme.filePinIcon
                    foreground: root.picker.currentItem?.pinned ? Theme.accent : Theme.inactive
                    hint: Translations.text(root.picker.currentItem?.pinned ? "clipboard.actions.unpinHint" : "clipboard.actions.pinHint")
                    enabled: !!root.picker.currentItem
                    onClicked: root.toggleCurrentPin()
                }
                UI.ActionButton {
                    glyph: Theme.deleteIcon
                    fillColor: Theme.urgent
                    hint: Translations.text("clipboard.actions.deleteHint")
                    enabled: !!root.picker.currentItem
                    onClicked: root.deleteCurrentEntry()
                }
                UI.ActionButton {
                    objectName: "clearClipboardHistory"
                    glyph: Theme.clearIcon
                    fillColor: Theme.urgent
                    hint: Translations.text("clipboard.actions.clearHint")
                    onClicked: ClipboardService.clear()
                }
                UI.ActionButton {
                    glyph: Theme.pasteIcon
                    enabled: !!root.picker.currentItem && root.picker.destination.length > 0
                    fillColor: Theme.accent
                    hint: Translations.text("clipboard.actions.pasteHint")
                    onClicked: root.picker.accept(false, false)
                }
            }
        }
    }
}
