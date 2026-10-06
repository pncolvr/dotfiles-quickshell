pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../"
import "../" as UI

QC.TabBar {
    id: root
    property var labels: []
    property real tabPadding: Theme.controlFieldPadding * 2
    property real baselineRightInset: 0
    property real underlineBottomMargin: 3
    signal tabClicked(int index)
    implicitHeight: Theme.controlHeight
    background: Rectangle {
        color: "transparent"
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.underlineBottomMargin
            width: Math.max(0, parent.width - root.baselineRightInset)
            height: 1
            color: Theme.empty
        }
    }
    Repeater {
        model: root.labels
        QC.TabButton {
            id: tabButton
            required property string modelData
            required property int index
            text: modelData
            width: implicitWidth
            implicitWidth: tabLabel.implicitWidth + root.tabPadding * 2
            implicitHeight: root.implicitHeight
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
                    anchors.bottomMargin: root.underlineBottomMargin
                    width: parent.width
                    height: 2
                    visible: tabButton.checked
                    color: Theme.accent
                }
            }
            onClicked: root.tabClicked(index)
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
}
