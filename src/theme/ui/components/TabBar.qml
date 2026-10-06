pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../"
import "../" as UI

QC.TabBar {
    id: root
    property var labels: []
    implicitHeight: Theme.controlHeight
    background: Rectangle {
        color: "transparent"
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.empty }
    }
    Repeater {
        model: root.labels
        QC.TabButton {
            id: tabButton
            required property string modelData
            text: modelData
            width: implicitWidth
            implicitWidth: tabLabel.implicitWidth + Theme.controlFieldPadding * 4
            implicitHeight: Theme.controlHeight
            padding: 0
            hoverEnabled: true
            contentItem: UI.Text {
                id: tabLabel
                centerVertical: false
                text: tabButton.text
                color: tabButton.checked ? Theme.accent : Theme.inactive
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: tabButton.down ? Qt.darker(Theme.alternateBackground, 1.2)
                    : tabButton.hovered ? Theme.alternateBackground : "transparent"
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    visible: tabButton.checked
                    color: Theme.accent
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
}
