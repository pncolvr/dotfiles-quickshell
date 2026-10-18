pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import ".." as UI

UI.SelectableRow {
    id: root
    property string description: ""
    property bool selected: false
    property bool wrapDescription: false
    property int descriptionAlignment: Text.AlignLeft
    padding: Theme.controlFieldPadding
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4
    Accessible.name: description
    readonly property bool keyboardFocusVisible: pointerFocus.keyboardFocusVisible
    UI.PointerFocus { id: pointerFocus }
    background: Rectangle {
        radius: Theme.iconButtonRadius
        color: root.pointerHovered || root.keyboardFocusVisible ? Theme.selectionHoverBackground
            : root.selected ? Theme.selectionSelectedBackground : Theme.selectionBackground
        border.width: root.highlighted || root.keyboardFocusVisible ? 1 : 0
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
