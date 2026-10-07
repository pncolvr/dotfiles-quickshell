pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Rectangle {
    id: root
    required property var file
    property var fileService: RecentFilesService
    readonly property string iconSource: Quickshell.iconPath(file.icon || "text-x-generic", true)
    property bool dragging: false
    implicitHeight: Theme.recentFilesRowHeight
    radius: Theme.iconButtonRadius
    color: hover.hovered || dragging ? Theme.alternateBackground : "transparent"

    Drag.dragType: Drag.Automatic
    Drag.active: fileDrag.active
    Drag.mimeData: ({"text/uri-list": root.file.uri + "\r\n"})
    Drag.supportedActions: Qt.CopyAction
    Drag.proposedAction: Qt.CopyAction
    Drag.imageSource: root.iconSource
    Drag.imageSourceSize: Qt.size(32, 32)
    Drag.hotSpot: Qt.point(16, 16)
    Drag.onDragStarted: {
        root.dragging = true
        root.fileService.beginDrag()
        TooltipService.beginDrag()
    }
    Drag.onDragFinished: root.finishDrag()
    function finishDrag() {
        if (!dragging) return
        dragging = false
        fileService.endDrag()
        TooltipService.endDrag()
    }
    Component.onDestruction: finishDrag()

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: root.fileService.openFile(root.file) }
    DragHandler { id: fileDrag; target: null; acceptedButtons: Qt.LeftButton }

    Image {
        id: icon
        x: Theme.controlFieldPadding
        anchors.verticalCenter: parent.verticalCenter
        width: 28; height: 28
        source: root.iconSource
        sourceSize: Qt.size(width, height)
    }
    Column {
        x: icon.x + icon.width + Theme.controlSpacing
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - x - Theme.controlFieldPadding
        spacing: 3
        UI.Text {
            centerVertical: false
            width: parent.width
            text: root.file.name
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
        }
        UI.Text {
            centerVertical: false
            width: parent.width
            text: root.file.directory + " · " + Qt.formatDateTime(new Date(root.file.usedAt), "dd MMM hh:mm")
            textFormat: Text.PlainText
            color: Theme.inactive
            font.pixelSize: 10
            elide: Text.ElideMiddle
        }
    }
}
