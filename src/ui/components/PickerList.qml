pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../services"
import "../../theme"
import ".." as UI

ListView {
    id: root
    activeFocusOnTab: true
    Rectangle { parent: root; anchors.fill: parent; z: 1; color: "transparent"; radius: Theme.iconButtonRadius; border.width: root.activeFocus ? 1 : 0; border.color: Theme.accent }
    required property var picker
    property bool showThumbnails: true
    property bool compactImages: false
    property real rowHeight: 0
    model: picker.filteredItems
    currentIndex: picker.currentIndex
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    orientation: picker.layout === "grid" ? ListView.Horizontal : ListView.Vertical
    spacing: Theme.controlSpacing
    highlightMoveDuration: 0
    QC.ScrollBar.vertical: UI.ScrollBar { visible: root.orientation === ListView.Vertical && needed }
    QC.ScrollBar.horizontal: UI.ScrollBar { visible: root.orientation === ListView.Horizontal && needed }
    onCurrentIndexChanged: {
        if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        if (picker.mode === PickerService.Mode.Clipboard && count >= 50
            && count === picker.filteredItems.length && currentIndex >= count - 8) picker.loadMoreClipboard()
    }
    onContentYChanged: if (moving && picker.mode === PickerService.Mode.Clipboard && contentHeight > height
        && contentY + height >= contentHeight - 200) picker.loadMoreClipboard()
    delegate: UI.PickerRow {
        required property var modelData
        required property int index
        entry: modelData
        showThumbnail: root.showThumbnails
        compactImage: root.compactImages
        height: root.rowHeight > 0 ? root.rowHeight : implicitHeight
        enabled: !root.picker.searchPending && !root.picker.searchFailed
        width: grid ? Math.max(80, (root.width - Theme.controlSpacing * 4) / 5) : root.width
        current: root.currentIndex === index
        selected: root.picker.selectedIds.includes(modelData.id)
        multiple: root.picker.multiple
        clipboard: root.picker.mode === PickerService.Mode.Clipboard
        grid: root.picker.layout === "grid"
        onChosen: toggle => root.picker.select(index, toggle || root.picker.multiple)
        onActivated: if (!root.picker.multiple) root.picker.accept(false, false)
    }
}
