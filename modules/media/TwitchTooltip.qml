pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI
import "../../services"

Item {
    id: root
    property bool adding: false
    readonly property int spacing: Theme.twitchTooltipSpacing
    readonly property var users: [...TwitchService.allUsers].sort((a, b) => {
        if (a.online === b.online) return a.login.localeCompare(b.login)
        return a.online ? -1 : 1
    })
    readonly property int rowWidth: Theme.twitchAvatarSize + Theme.twitchInfoWidth + Theme.twitchRemoveButtonSize + 2 * Theme.twitchUserSpacing
    readonly property int columns: Math.min(3, Math.max(1, users.length), Math.max(1,
        Math.floor(((TooltipService.screen?.width ?? 1920) - 2 * Theme.tooltipPaddingWidth
            - Theme.twitchScrollbarWidth - Theme.twitchScrollbarMargin + spacing) / (rowWidth + spacing))))
    implicitWidth: columns * rowWidth + (columns - 1) * spacing
        + (scrollbar.visible ? Theme.twitchScrollbarWidth + Theme.twitchScrollbarMargin : 0)
    implicitHeight: content.implicitHeight

    function cancelEditor() { adding = false; loginField.clear() }
    function addUser() {
        if (TwitchService.addUser(loginField.text)) cancelEditor()
    }

    Column {
        id: content
        width: root.width
        spacing: root.spacing

        QC.ScrollView {
            width: root.width
            height: Math.min(usersGrid.implicitHeight, (TooltipService.screen?.height ?? 1080) * Theme.twitchTooltipMaxHeightRatio)
            visible: root.users.length > 0
            clip: true
            contentWidth: usersGrid.implicitWidth
            contentHeight: usersGrid.implicitHeight
            QC.ScrollBar.horizontal.policy: QC.ScrollBar.AlwaysOff
            QC.ScrollBar.vertical: QC.ScrollBar {
                id: scrollbar
                implicitWidth: Theme.twitchScrollbarWidth
                visible: usersGrid.implicitHeight > parent.height
                policy: QC.ScrollBar.AsNeeded
                contentItem: Rectangle { radius: width / 2; color: Theme.accent; opacity: scrollbar.active ? 1 : 0.5 }
                background: Rectangle { color: Theme.empty; radius: width / 2 }
            }
            Grid {
                id: usersGrid
                columns: root.columns
                spacing: root.spacing
                verticalItemAlignment: Grid.AlignVCenter
                Repeater {
                    model: root.users
                    delegate: TwitchUserRow {
                        required property var modelData
                        user: modelData
                    }
                }
            }
        }

        Text {
            visible: !root.users.length
            text: "No streamers yet — add one below"
            color: Theme.inactive
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        // Keep the footer height stable when the editor opens, as in TOTP.
        Item {
            width: root.width
            height: Theme.twitchEditorHeight

            UI.ActionButton {
                objectName: "beginAddTwitchUser"
                anchors.right: parent.right
                width: Theme.twitchEditorButtonWidth
                height: Theme.twitchEditorHeight
                glyph: Theme.addIcon
                hint: "Add streamer"
                visible: !root.adding
                enabled: TwitchService.usersReady
                onClicked: {
                    root.adding = true
                    Qt.callLater(() => loginField.forceActiveFocus())
                }
            }

            Row {
                width: parent.width
                spacing: root.spacing
                visible: root.adding

                UI.InputField {
                    id: loginField
                    objectName: "twitchLoginField"
                    width: parent.width - 2 * (Theme.twitchEditorButtonWidth + parent.spacing)
                    height: Theme.twitchEditorHeight
                    placeholderText: "Streamer login"
                    maximumLength: 25
                    enabled: TwitchService.usersReady
                    Accessible.name: "Streamer login"
                    onAccepted: root.addUser()
                    Keys.onEscapePressed: root.cancelEditor()
                }
                UI.ActionButton {
                    objectName: "cancelAddTwitchUser"
                    glyph: Theme.cancelIcon
                    hint: "Cancel"
                    width: Theme.twitchEditorButtonWidth
                    height: Theme.twitchEditorHeight
                    onClicked: root.cancelEditor()
                }
                UI.ActionButton {
                    objectName: "addTwitchUser"
                    glyph: Theme.addIcon
                    hint: "Add streamer"
                    width: Theme.twitchEditorButtonWidth
                    height: Theme.twitchEditorHeight
                    fillColor: Theme.accent
                    enabled: TwitchService.usersReady && loginField.text.trim().length > 0
                    onClicked: root.addUser()
                }
            }
        }

        Text {
            width: root.width
            visible: text.length > 0
            text: TwitchService.error
            color: Theme.warning
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
