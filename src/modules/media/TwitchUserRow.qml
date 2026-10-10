pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import "../../theme/ui" as UI
import "../../theme"
import "../../services"

Row {
    id: root
    spacing: Theme.twitchUserSpacing
    width: Theme.twitchAvatarSize + Theme.twitchInfoWidth + controls.implicitWidth + 2 * spacing

    required property var user
    readonly property string mainLogin: user.mainLogin ?? user.login
    objectName: "twitchUserRow_" + mainLogin
    signal editRequested(string login)

    opacity: user.online ? 1.0 : 0.4

    // Avatar
    Item {
        width: Theme.twitchAvatarSize
        height: width

        Image {
            id: avatarImage
            objectName: "twitchAvatar_" + root.user.login
            anchors.fill: parent
            source: root.user.avatar || ""
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
        objectName: "twitchUserDetails_" + root.mainLogin
        width: Math.max(0, root.width - Theme.twitchAvatarSize - controls.implicitWidth - 2 * root.spacing)
        height: Math.max(Theme.twitchAvatarSize, info.implicitHeight)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: TwitchService.openUrl(root.user.login)
        }
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
                    UI.HoverTooltip { text: parent.text }
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

            UI.ColumnText {
                objectName: "twitchSecondChannelLabel_" + root.mainLogin
                visible: root.user.usingFallback === true
                text: "Second channel for " + root.mainLogin
                color: Theme.inactive
                elide: Text.ElideRight
                width: parent.width
                centerVertical: false
                UI.HoverTooltip { text: parent.text }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: TwitchService.openUrl(root.mainLogin)
                }
            }

            UI.ColumnText {
                visible: !root.user.online && !!root.user.nextStream
                text: root.user.nextStream ?? ""
                color: Theme.inactive
                elide: Text.ElideRight
                width: parent.width
                centerVertical: false
                UI.HoverTooltip { text: parent.text }
            }
        }
    }

    Row {
        id: controls
        spacing: Theme.controlSpacing
        anchors.verticalCenter: parent.verticalCenter

        UI.ActionButton {
            objectName: "editTwitchUser_" + root.mainLogin
            glyph: Theme.editIcon
            hint: "edit channel"
            enabled: TwitchService.usersReady
            onClicked: root.editRequested(root.mainLogin)
        }

        UI.ActionButton {
            objectName: "removeTwitchUser_" + root.mainLogin
            glyph: Theme.deleteIcon
            hint: "remove streamer"
            fillColor: Theme.urgent
            enabled: TwitchService.usersReady
            onClicked: TwitchService.removeUser(root.mainLogin)
        }
    }
}
