import QtQuick
import "../"
import "./components" as UI

Rectangle {
    property alias text: label.text
    property color badgeColor: Theme.urgent

    radius: Theme.statusBadgeRadius
    color: badgeColor
    implicitWidth: label.implicitWidth + Theme.statusBadgePaddingWidth
    implicitHeight: label.implicitHeight + Theme.statusBadgePaddingHeight

    UI.Text {
        id: label
        anchors.centerIn: parent
    }
}