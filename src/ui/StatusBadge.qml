import QtQuick
import "../theme"
import "./components" as UI

Item {
    id: root
    property alias text: label.text
    property color badgeColor: Theme.urgent
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    implicitWidth: label.implicitWidth + Theme.statusBadgePaddingWidth + Theme.workspaceSpacing
    implicitHeight: label.implicitHeight + Theme.statusBadgePaddingHeight

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.workspaceSpacing / 2
        anchors.rightMargin: Theme.workspaceSpacing / 2
        radius: Theme.statusBadgeRadius
        color: root.badgeColor
    }

    UI.Text {
        id: label
        anchors.centerIn: parent
    }
}
