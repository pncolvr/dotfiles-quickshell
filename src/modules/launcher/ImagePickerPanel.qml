pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"

PickerPanelBase {
    id: root
    searchPlaceholder: "Search images"
    showThumbnails: false
    readonly property bool sideBySide: availableContentWidth >= Theme.pickerWidth + 240
    implicitWidth: sideBySide ? availableContentWidth : Math.min(Theme.pickerWidth, availableContentWidth)
    implicitHeight: Math.max(normalHeight, availableContentHeight)
    fixedListWidth: sideBySide ? Theme.pickerWidth - Theme.tooltipPaddingHeight * 2 : 0
    stackedPreview: !sideBySide
    previewComponent: Component {
        ClipboardImagePreview {
            entries: root.picker.filteredItems
            entry: root.picker.currentItem
            decodeWidth: root.sideBySide ? Math.max(1, root.availableContentWidth - Theme.pickerWidth) : root.availableContentWidth
            decodeHeight: root.sideBySide ? root.availableContentHeight : root.availableContentHeight * 0.5
        }
    }
}
