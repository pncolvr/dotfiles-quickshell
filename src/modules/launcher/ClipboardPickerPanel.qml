pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui" as UI
import "../../services"
import "../../config"

PreviewPickerPanel {
    id: root
    searchPlaceholder: PickerPrompts.text("clipboard", "clipboard.search.placeholder")
    panelError: picker.error || ClipboardService.error
    minimumRowHeight: Theme.clipboardRowHeight
    readonly property bool imagesOnly: picker.itemCriteria.kind === "image"
    function resetPreview() { previewEnabled = imagesOnly || initialPreviewEnabled }
    previewKind: "clipboard"
    compactImageRows: previewEnabled
    onPreviewEnabledChanged: sizeListForOpening()
    previewShortcut: false // The existing Images only action also toggles its preview.
    onImagesOnlyChanged: previewEnabled = imagesOnly
    function setCriterion(name,value) {
        const criteria = Object.assign({},picker.itemCriteria)
        if (value === undefined) delete criteria[name]
        else criteria[name] = value
        picker.itemCriteria = criteria
        picker.currentIndex = 0
    }
    function toggleImagesOnly() { setCriterion("kind",imagesOnly ? undefined : "image") }
    readonly property bool pinnedOnly: picker.itemCriteria.pinned === true
    hintPanel: "clipboard"
    hintOverrides: ({preview: {label: Translations.text("clipboard.filter.images")}})
    hintActions: ["clipboard.pinnedOnly", "preview"].concat(root.picker.currentItem ? ["clipboard.pin", "copy", "clipboard.delete"] : [])
    function sizeListForOpening() {
        const entries = picker.items.slice(0, maximumListRows)
        openedListHeight = entries.length ? entries.reduce((height, entry) => height + (previewEnabled
            ? measuredRowHeight : entry.image ? Theme.clipboardImagePreviewHeight + Theme.pickerRowPadding * 2 : Theme.clipboardRowHeight), 0)
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
    Keys.onPressed: event => {
        if (UI.Keybinds.matches(event, "copy")) root.picker.accept(false, true)
        else if (UI.Keybinds.matches(event, "clipboard.delete")) root.deleteCurrentEntry()
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
