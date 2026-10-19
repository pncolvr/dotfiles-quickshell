pragma ComponentBehavior: Bound
import QtQuick
import "../../ui" as UI
import "../../theme"

Column {
    id: section
    required property var updates
    required property color nameColor
    width: parent.width
    spacing: Theme.controlSpacing
    visible: updates.length > 0
    Item {
        width: parent.width
        height: countLabel.implicitHeight
        Rectangle {
            anchors.left: parent.left
            anchors.right: countLabel.left
            anchors.rightMargin: Theme.controlSpacing
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Theme.empty
        }
        UI.ColumnText {
            id: countLabel
            objectName: section.objectName + "Count"
            anchors.right: parent.right
            text: String(section.updates.length)
            color: section.nameColor
        }
    }
    Repeater {
        model: section.updates
        delegate: UpdateRow {
            required property var modelData
            update: modelData
            nameColor: section.nameColor
        }
    }
}
