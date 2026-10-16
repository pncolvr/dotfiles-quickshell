pragma ComponentBehavior: Bound
import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI

Column {
    id: root
    required property string label
    required property string value
    required property real ratio
    property string hint: ""
    property color fillColor: ratio >= 0.9 ? Theme.urgent : ratio >= 0.7 ? Theme.warning : Theme.accent
    spacing: 4
    Item {
        width: parent.width
        height: Theme.fontSize + 2
        UI.ColumnText { anchors.left: parent.left; text: root.label; color: Theme.inactive }
        UI.ColumnText { anchors.right: parent.right; text: root.value }
    }
    Rectangle {
        objectName: "statsBarTrack"
        width: parent.width
        height: 4
        radius: 2
        color: Theme.empty
        Rectangle {
            objectName: "statsBarFill"
            width: parent.width * Math.max(0, Math.min(1, root.ratio))
            height: parent.height
            radius: parent.radius
            color: root.fillColor
        }
        UI.HoverTooltip { text: root.hint; enabled: root.hint.length > 0 }
    }
}
