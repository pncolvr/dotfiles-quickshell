pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    default property alias contentData: content.data
    implicitHeight: content.height + Theme.controlSpacing + 1
    Rectangle {
        width: parent.width
        height: content.height
        visible: hover.hovered
        color: Theme.alternateBackground
        radius: Theme.iconButtonRadius
    }
    HoverHandler { id: hover }
    RowLayout {
        id: content
        width: parent.width
        height: Math.max(Theme.controlHeight,implicitHeight)
        spacing: Theme.controlSpacing
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.empty
    }
}
