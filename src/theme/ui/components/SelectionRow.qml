pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../"
import "../" as UI

QC.ItemDelegate {
    id: root
    property string description: ""
    property bool selected: false
    property bool wrapDescription: false
    property int descriptionAlignment: Text.AlignLeft
    padding: Theme.controlFieldPadding
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4
    Accessible.name: description
    UI.PointerFocus {}
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    background: Rectangle {
        radius: Theme.iconButtonRadius
        color: root.hovered || root.visualFocus ? Theme.selectionHoverBackground
            : root.selected ? Theme.selectionSelectedBackground : Theme.selectionBackground
        border.width: root.highlighted || root.visualFocus ? 1 : 0
        border.color: Theme.accent
    }
    contentItem: Item {
        implicitHeight: label.implicitHeight
        UI.ColumnText {
            id: label
            anchors.left: parent.left
            anchors.right: mark.left
            anchors.rightMargin: Theme.controlSpacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.description
            textFormat: Text.PlainText
            horizontalAlignment: root.descriptionAlignment
            wrapMode: root.wrapDescription ? Text.Wrap : Text.NoWrap
            maximumLineCount: root.wrapDescription ? 2 : 1
            elide: Text.ElideRight
            color: root.selected ? Theme.accent : Theme.text
        }
        UI.IconText {
            id: mark
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.checkIcon
            opacity: root.selected ? 1 : 0
            color: Theme.accent
        }
    }
}
