pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import "../../theme/ui" as UI
import "../../theme"
import "../../services"

Row {
// Column {
    id: root
    spacing: 8

    required property var user

    opacity: user.online ? 1.0 : 0.4

    // Avatar
    Item {
        width: Theme.twitchAvatarSize
        height: Theme.twitchAvatarSize
        // anchors.horizontalCenter: parent.horizontalCenter

        Image {
            id: avatarImage
            anchors.fill: parent
            source: `file://${root.user.avatar}`
            fillMode: Image.PreserveAspectCrop
            smooth: true
            visible: false
        }

        Rectangle {
            id: avatarMask
            anchors.fill: parent
            radius: width / 2
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: avatarImage
            maskSource: avatarMask
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: root.user.online ? Theme.twitchColor : Theme.tooltipBackground
            border.width: 3
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: TwitchService.openUrl(root.user.login)
        }
    }

    // Info
    Item {
        width: Theme.twitchInfoWidth
        height: Theme.twitchAvatarSize
        Column {
            id: info
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter

            RowLayout {
                width: parent.width
                spacing: 4

                UI.ColumnText {
                    text: root.user.login
                    color: root.user.online ? Theme.text : Theme.inactive
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width / 2
                    centerVertical: false
                }

                UI.ColumnText {
                    visible: root.user.online
                    text: "·"
                    color: root.user.online ? Theme.text : Theme.inactive
                    centerVertical: false
                }

                UI.ColumnText {
                    visible: root.user.online
                    text: root.user.online ? root.user.game : ""
                    color: root.user.online ? Theme.text : Theme.inactive
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                    centerVertical: false
                    UI.HoverTooltip { text: root.user.game }
                }
            }

            RowLayout {
                visible: root.user.online
                width: parent.width
                spacing: 4

                UI.ColumnText {
                    text: root.user.online ? root.user.viewers : ""
                    color: root.user.online ? Theme.text : Theme.inactive
                    Layout.preferredWidth: implicitWidth
                    centerVertical: false
                }

                UI.ColumnText {
                    text: "·"
                    color: root.user.online ? Theme.text : Theme.inactive
                    centerVertical: false
                }

                UI.ColumnText {
                    text: root.user.online ? root.user.title : ""
                    color: root.user.online ? Theme.text : Theme.inactive
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                    centerVertical: false
                    UI.HoverTooltip { text: parent.text }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.user.online ? TwitchService.openStream(root.user.login) : TwitchService.openUrl(root.user.login)
        }
    }
}