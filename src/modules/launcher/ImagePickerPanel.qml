pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"

PickerPanelBase {
    id: root
    searchPlaceholder: "Search images"
    showThumbnails: false
    readonly property bool sideBySide: availableContentWidth >= Theme.pickerWidth + 240
    placementWidth: sideBySide ? availableContentWidth : implicitWidth
    // Keep the last known aspect while the shared loader reads the next header.
    property real previewAspectRatio: 0
    readonly property real previewPadding: Theme.controlSpacing * 2
    readonly property real previewWidthLimit: Math.max(0, availableContentWidth - Theme.pickerWidth - Theme.controlSpacing - previewPadding)
    readonly property real previewHeightLimit: Math.max(0, availableContentHeight - previewVerticalPadding - previewPadding)
    readonly property real fittedPreviewWidth: previewAspectRatio > 0
        ? Math.min(previewWidthLimit, previewHeightLimit * previewAspectRatio) : previewWidthLimit
    readonly property real fittedPreviewHeight: previewAspectRatio > 0 ? fittedPreviewWidth / previewAspectRatio : previewHeightLimit
    implicitWidth: sideBySide ? Math.min(availableContentWidth,
        Theme.pickerWidth + Theme.controlSpacing + previewPadding + fittedPreviewWidth) : Math.min(Theme.pickerWidth, availableContentWidth)
    // Keep the list viewport and scroll position steady across aspect changes.
    implicitHeight: Math.max(normalHeight, availableContentHeight)
    maximumPreviewHeight: sideBySide && previewAspectRatio > 0 ? fittedPreviewHeight + previewPadding : 0
    fixedListWidth: sideBySide ? Theme.pickerWidth - Theme.tooltipPaddingHeight * 2 : 0
    stackedPreview: !sideBySide
    previewComponent: Component {
        ClipboardImagePreview {
            entries: root.picker.filteredItems
            entry: root.picker.currentItem
            decodeWidth: root.sideBySide ? Math.max(1, root.availableContentWidth - Theme.pickerWidth) : root.availableContentWidth
            decodeHeight: root.sideBySide ? root.availableContentHeight : root.availableContentHeight * 0.5
            onNaturalSizeChanged: {
                if (naturalSize.width > 0 && naturalSize.height > 0)
                    root.previewAspectRatio = naturalSize.width / naturalSize.height
            }
        }
    }
}
