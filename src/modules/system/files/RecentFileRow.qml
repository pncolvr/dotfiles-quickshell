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
    property var selection: null
    readonly property bool selected: selection?.selectedUris.includes(file.uri) ?? false
    readonly property bool pinned: fileService.isPinned(file.uri)
    readonly property string iconSource: Quickshell.iconPath(file.icon || "text-x-generic", true)
    readonly property bool dragging: selection?.dragSource.dragging === true
        && selection.dragSource.files.some(entry => entry.uri === file.uri)
    implicitHeight: Theme.recentFilesRowHeight
    radius: Theme.iconButtonRadius
    color: hover.hovered || dragging ? Theme.alternateBackground : "transparent"
    border.width: selected ? 1 : 0
    border.color: Theme.accent

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: mouse => root.selection?.selectFile(root.file.uri, mouse.modifiers)
        onDoubleClicked: mouse => {
            if (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) mouse.accepted = false
            else root.fileService.openFile(root.file)
        }
    }
    DragHandler {
        id: fileDrag
        target: null
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            if (active) root.selection?.startFileDrag(root.file.uri, centroid.modifiers)
        }
    }

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
        width: pin.visible ? pin.x - x - Theme.controlSpacing : root.width - x - Theme.controlFieldPadding
        spacing: 3
        UI.Text {
            objectName: "fileName"
            centerVertical: false
            width: Math.min(implicitWidth, parent.width)
            text: root.file.name
            color: root.selected ? Theme.accent : Theme.text
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            HoverHandler { id: nameHover; cursorShape: Qt.PointingHandCursor }
            UI.HoverTooltip {
                objectName: "fileNameTooltip"
                hoverTarget: nameHover
                enabled: !root.dragging
                text: root.file.name
            }
        }
        UI.Text {
            centerVertical: false
            width: Math.min(implicitWidth, parent.width)
            text: root.file.directory + " · " + Qt.formatDateTime(new Date(root.file.usedAt), "dd MMM hh:mm")
            textFormat: Text.PlainText
            color: Theme.inactive
            font.pixelSize: 10
            elide: Text.ElideMiddle
            HoverHandler { id: directoryHover; cursorShape: Qt.PointingHandCursor }
            UI.HoverTooltip {
                objectName: "fileDirectoryTooltip"
                hoverTarget: directoryHover
                enabled: !root.dragging
                text: root.file.directory
            }
        }
    }
    UI.ActionButton {
        id: pin
        objectName: "pinFile"
        anchors.right: parent.right
        anchors.rightMargin: Theme.controlFieldPadding
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.file.isDirectory
        enabled: !root.fileService.dragging
        glyph: Theme.filePinIcon
        foreground: root.pinned ? Theme.accent : Theme.inactive
        fillColor: "transparent"
        hint: root.pinned ? "Unpin file" : "Pin file"
        onClicked: root.fileService.togglePin(root.file)
    }
}
