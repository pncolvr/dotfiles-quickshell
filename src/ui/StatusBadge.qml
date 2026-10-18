import QtQuick
import "../theme"
import "./components" as UI

Item {
    id: root
    property alias text: label.text
    property color badgeColor: Theme.urgent
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    implicitWidth: label.implicitWidth + Theme.statusBadgePaddingWidth + Theme.moduleSpacing
    implicitHeight: label.implicitHeight + Theme.statusBadgePaddingHeight

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.moduleSpacing / 2
        anchors.rightMargin: Theme.moduleSpacing / 2
        radius: Theme.statusBadgeRadius
        color: root.badgeColor
    }

    UI.Text {
        id: label
        anchors.centerIn: parent
    }
}
