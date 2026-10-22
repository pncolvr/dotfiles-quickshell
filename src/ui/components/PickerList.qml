pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../services"
import "../../theme"
import ".." as UI

ListView {
    id: root
    property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: root }
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
    leftMargin: orientation === ListView.Vertical ? Theme.scrollbarGutter : 0
    rightMargin: leftMargin
    topMargin: orientation === ListView.Horizontal ? Theme.scrollbarGutter : 0
    bottomMargin: topMargin
    // ListView owns delegate positions; inset the cross-axis viewport instead.
    Binding on contentX {
        when: root.orientation === ListView.Vertical
        value: -Theme.scrollbarGutter
        restoreMode: Binding.RestoreNone
    }
    Binding on contentY {
        when: root.orientation === ListView.Horizontal
        value: -Theme.scrollbarGutter
        restoreMode: Binding.RestoreNone
    }
    spacing: Theme.controlSpacing
    highlightMoveDuration: 0
    QC.ScrollBar.vertical: UI.ScrollBar { policy: root.orientation === ListView.Vertical ? QC.ScrollBar.AsNeeded : QC.ScrollBar.AlwaysOff }
    QC.ScrollBar.horizontal: UI.ScrollBar { policy: root.orientation === ListView.Horizontal ? QC.ScrollBar.AsNeeded : QC.ScrollBar.AlwaysOff }
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
        height: grid ? Math.max(0, root.height - Theme.scrollbarGutter * 2) : root.rowHeight > 0 ? root.rowHeight : implicitHeight
        enabled: !root.picker.searchPending && !root.picker.searchFailed
        width: grid ? Math.max(80, (root.width - Theme.controlSpacing * 4) / 5) : Math.max(0, root.width - Theme.scrollbarGutter * 2)
        current: root.currentIndex === index
        selected: root.picker.selectedIds.includes(modelData.id)
        multiple: root.picker.multiple
        clipboard: root.picker.mode === PickerService.Mode.Clipboard
        grid: root.picker.layout === "grid"
        onChosen: toggle => root.picker.select(index, toggle || root.picker.multiple)
        onActivated: if (!root.picker.multiple) root.picker.accept(false, false)
    }
}
