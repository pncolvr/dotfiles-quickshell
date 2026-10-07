pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../"
import "../" as UI

Rectangle {
    id: root
    required property var entry
    property bool current: false
    property bool selected: false
    property bool multiple: false
    property bool clipboard: false
    property bool grid: false
    signal chosen(bool toggle)
    signal activated()
    color: current ? Theme.accent : hover.hovered ? Theme.alternateBackground : "transparent"
    radius: Theme.iconButtonRadius
    implicitHeight: grid ? Theme.pickerGridHeight : Math.max(
        textBlock.implicitHeight + Theme.pickerRowPadding * 2,
        thumbnail.visible ? thumbnail.height + Theme.pickerRowPadding * 2 : 0)
    height: implicitHeight
    Accessible.name: entry.title
    Accessible.role: multiple ? Accessible.CheckBox : Accessible.ListItem
    Accessible.checkable: multiple
    Accessible.checked: selected

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    MouseArea {
        anchors.fill: parent
        onClicked: mouse => {
            root.chosen((mouse.modifiers & Qt.ControlModifier) !== 0)
            if (!root.clipboard) root.activated()
        }
        onDoubleClicked: if (root.clipboard) root.activated()
    }
    UI.Icon {
        id: selectionBox
        anchors.left: parent.left
        anchors.leftMargin: Theme.controlFieldPadding
        anchors.verticalCenter: parent.verticalCenter
        width: 16; height: 16
        visible: root.multiple
        color: "transparent"
        radius: 3
        border.width: 1
        border.color: root.current || root.selected ? Theme.text : Theme.inactive
        text: root.selected ? Theme.checkIcon : ""
    }
    Image {
        id: thumbnail
        anchors.left: parent.left
        anchors.leftMargin: Theme.controlFieldPadding + (root.multiple ? selectionBox.width + Theme.controlSpacing : 0)
        anchors.verticalCenter: parent.verticalCenter
        width: root.clipboard ? 44 : 18
        height: root.clipboard ? 36 : 18
        source: root.entry.image || (root.entry.icon ? Quickshell.iconPath(root.entry.icon, true) : "")
        visible: source.toString().length > 0 && !root.grid
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(120, 120)
        asynchronous: true
    }
    Column {
        id: textBlock
        anchors.left: parent.left
        anchors.leftMargin: Theme.controlFieldPadding + (root.multiple ? selectionBox.width + Theme.controlSpacing : 0)
            + (thumbnail.visible ? thumbnail.width + Theme.controlSpacing : 0)
        anchors.right: parent.right
        anchors.rightMargin: Theme.controlFieldPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        UI.IconText {
            centerVertical: false
            width: parent.width
            visible: root.grid && text.length > 0
            text: root.entry.glyph || ""
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
        }
        UI.Text {
            centerVertical: false
            width: parent.width
            // Legacy power labels contain Pango markup; normalize their grid presentation.
            text: root.grid ? root.entry.title.replace(/<[^>]*>/g, "").trim() : root.entry.title
            textFormat: Text.PlainText
            horizontalAlignment: root.grid ? Text.AlignHCenter : Text.AlignLeft
            wrapMode: root.clipboard ? Text.Wrap : Text.NoWrap
            maximumLineCount: root.clipboard ? 2 : 1
            elide: Text.ElideRight
        }
        UI.Text {
            centerVertical: false
            width: parent.width
            text: root.entry.subtitle || ""
            visible: text.length > 0 && !root.grid
            textFormat: Text.PlainText
            color: root.current ? Theme.text : Theme.inactive
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
        }
    }
}
