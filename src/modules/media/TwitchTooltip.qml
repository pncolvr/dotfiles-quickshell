pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI
import "../../services"

Item {
    id: root
    property bool adding: false
    property var users: TwitchService.allUsers
    property alias searchText: searchField.text
    readonly property string searchQuery: adding ? "" : searchField.query
    readonly property var filteredUsers: users.filter(user => !searchQuery
        || [user.login, user.game, user.title].some(value => String(value ?? "").toLowerCase().includes(searchQuery)))
    readonly property var liveUsers: filteredUsers.filter(user => user.online).sort((a, b) => a.login.localeCompare(b.login))
    readonly property var offlineUsers: filteredUsers.filter(user => !user.online).sort((a, b) => a.login.localeCompare(b.login))
    readonly property var browserSuggestions: TwitchService.browserSuggestions.filter(login =>
        login.includes(loginField.text.trim().toLowerCase().replace(/^(?:https?:\/\/)?(?:www\.|m\.)?twitch\.tv\//, "").split(/[/?#]/)[0]))
    readonly property bool hasSuggestions: adding && browserSuggestions.length > 0
    readonly property bool hasUndo: TwitchService.removedUsers.length > 0
    readonly property int spacing: Theme.twitchTooltipSpacing
    readonly property int scrollbarSpace: Theme.twitchScrollbarWidth + Theme.twitchScrollbarMargin
    readonly property int rowWidth: Theme.twitchAvatarSize + Theme.twitchInfoWidth + Theme.twitchRemoveButtonSize + 2 * Theme.twitchUserSpacing
    readonly property int widthColumns: Math.min(2, Math.max(1, users.filter(user => user.online).length,
        users.filter(user => !user.online).length), Math.max(1,
        Math.floor(((TooltipService.screen?.width ?? 1920) - 2 * Theme.tooltipPaddingWidth
            - scrollbarSpace + spacing) / (rowWidth + spacing))))
    readonly property real maximumHeight: Math.max(0, Math.min(
        (TooltipService.screen?.height ?? 1080) * Theme.twitchTooltipMaxHeightRatio,
        (TooltipService.screen?.height ?? 1080) - Theme.barHeight - Theme.tooltipPaddingHeight * 2))
    readonly property real fixedHeight: divider.height + editor.height + spacing * 2
        + (hasSuggestions ? suggestionsHeader.height + spacing * 2 : 0)
        + (hasUndo ? undoHeader.height + spacing * 2 : 0)
        + (errorText.visible ? errorText.height + spacing : 0)
    readonly property real scrollBudget: Math.max(0, maximumHeight - fixedHeight)
    readonly property real suggestionsHeight: hasSuggestions
        ? Math.min(suggestionsView.gridHeight,
            Theme.twitchSuggestionMaxRows * (Theme.twitchEditorHeight + spacing) - spacing,
            scrollBudget * 0.4) : 0
    readonly property real undoHeight: hasUndo
        ? Math.min(undoView.gridHeight,
            Theme.twitchSuggestionMaxRows * (Theme.twitchEditorHeight + spacing) - spacing,
            scrollBudget * 0.3) : 0
    implicitWidth: widthColumns * rowWidth + (widthColumns - 1) * spacing + scrollbarSpace
    implicitHeight: content.implicitHeight
    onSearchQueryChanged: {
        const view = usersView.contentItem as Flickable
        if (view) view.contentY = 0
    }

    function cancelEditor() { adding = false; loginField.clear() }
    function addUser() {
        if (TwitchService.addUser(loginField.text)) cancelEditor()
    }
    function addSuggestion(login) {
        if (!TwitchService.addUser(login)) return
        if (!TwitchService.browserSuggestions.length) cancelEditor()
        else Qt.callLater(() => loginField.forceActiveFocus())
    }
    function addAllSuggestions() {
        const logins = [...browserSuggestions]
        if (!logins.length) return
        for (const login of logins) {
            if (!TwitchService.addUser(login)) return
        }
        cancelEditor()
    }

    Timer {
        interval: 3000
        running: root.adding
        repeat: true
        triggeredOnStart: true
        onTriggered: TwitchService.refreshBrowserSuggestions()
    }

    Column {
        id: content
        width: root.width
        spacing: root.spacing

        QC.ScrollView {
            id: usersView
            objectName: "twitchUsersScrollView"
            // Keep the rows aligned with the footer; the scrollbar uses the tooltip's right padding.
            width: root.width + root.scrollbarSpace
            height: Math.min(usersContent.implicitHeight, Math.max(0, root.scrollBudget - root.suggestionsHeight - root.undoHeight))
            clip: true
            contentWidth: root.width
            contentHeight: usersContent.implicitHeight
            QC.ScrollBar.horizontal.policy: QC.ScrollBar.AlwaysOff
            QC.ScrollBar.vertical: QC.ScrollBar {
                id: usersScrollbar
                x: usersView.width - width
                height: usersView.height
                implicitWidth: Theme.twitchScrollbarWidth
                visible: usersContent.implicitHeight > usersView.height
                policy: QC.ScrollBar.AsNeeded
                contentItem: Rectangle { radius: width / 2; color: Theme.accent; opacity: usersScrollbar.active ? 1 : 0.5 }
                background: Rectangle { color: Theme.empty; radius: width / 2 }
            }
            Column {
                id: usersContent
                width: usersView.contentWidth
                spacing: root.spacing * 2

                TwitchUserSection {
                    objectName: "twitchLiveUsersSection"
                    width: parent.width
                    title: "Live"
                    users: root.liveUsers
                    columns: 1
                    forceExpanded: root.searchQuery.length > 0
                }
                TwitchUserSection {
                    objectName: "twitchOfflineUsersSection"
                    width: parent.width
                    title: "Offline"
                    expanded: false
                    users: root.offlineUsers
                    columns: 1
                    forceExpanded: root.searchQuery.length > 0
                }
                UI.ColumnText {
                    visible: !root.users.length
                    text: "No streamers yet — add one below"
                    color: Theme.inactive
                }
                UI.ColumnText {
                    objectName: "twitchSearchEmpty"
                    visible: root.users.length > 0 && !root.filteredUsers.length
                    text: "No matching streamers."
                    color: Theme.inactive
                }
            }
        }

        Rectangle {
            id: divider
            width: root.width
            height: 1
            color: Theme.empty
        }

        Item {
            id: editor
            objectName: "twitchEditorFooter"
            width: root.width
            height: Theme.twitchEditorHeight

            UI.SearchField {
                id: searchField
                objectName: "twitchSearchField"
                anchors.left: parent.left
                anchors.right: addButton.left
                anchors.rightMargin: root.spacing
                height: parent.height
                visible: !root.adding
                placeholderText: "Search streamers…"
            }

            UI.ActionButton {
                id: addButton
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
                objectName: "twitchEditorControls"
                anchors.right: parent.right
                width: parent.width
                spacing: root.spacing
                visible: root.adding

                UI.InputField {
                    id: loginField
                    objectName: "twitchLoginField"
                    width: parent.width - 2 * (Theme.twitchEditorButtonWidth + parent.spacing)
                    height: Theme.twitchEditorHeight
                    placeholderText: "Login or Twitch URL"
                    enabled: TwitchService.usersReady
                    Accessible.name: "Streamer login or Twitch URL"
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

        Item {
            id: suggestionsHeader
            width: root.width
            height: Theme.twitchEditorHeight
            visible: root.hasSuggestions

            UI.ColumnText {
                id: browserHeading
                anchors.left: parent.left
                anchors.verticalCenterOffset: (height - headingMetrics.tightBoundingRect.height) / 2
                    - baselineOffset - headingMetrics.tightBoundingRect.y
                width: parent.width - addAllButton.width - root.spacing
                text: "Open in qutebrowser"
                color: Theme.inactive
                elide: Text.ElideRight
                centerVertical: true
            }
            TextMetrics {
                id: headingMetrics
                font: browserHeading.font
                text: browserHeading.text
            }
            UI.ActionButton {
                id: addAllButton
                objectName: "addAllBrowserTwitchUsers"
                anchors.right: parent.right
                width: implicitContentWidth
                height: Theme.twitchEditorHeight
                label: "Add all (" + root.browserSuggestions.length + ")"
                hint: "Add all " + root.browserSuggestions.length + " suggested streamers"
                fillColor: Theme.accent
                enabled: TwitchService.usersReady && root.browserSuggestions.length > 0
                onClicked: root.addAllSuggestions()
            }
        }

        TwitchActionGrid {
            id: suggestionsView
            objectName: "twitchBrowserSuggestions"
            width: root.width
            height: root.suggestionsHeight
            visible: root.hasSuggestions
            logins: root.browserSuggestions
            gridObjectName: "twitchSuggestionsGrid"
            enabled: TwitchService.usersReady
            onSelected: login => root.addSuggestion(login)
        }

        Item {
            id: undoHeader
            width: root.width
            height: Theme.twitchEditorHeight
            visible: root.hasUndo

            UI.ColumnText {
                id: undoHeading
                anchors.left: parent.left
                anchors.verticalCenterOffset: (height - undoHeadingMetrics.tightBoundingRect.height) / 2
                    - baselineOffset - undoHeadingMetrics.tightBoundingRect.y
                width: parent.width - undoAllButton.width - root.spacing
                text: "Recently removed"
                color: Theme.inactive
                elide: Text.ElideRight
                centerVertical: true
            }
            TextMetrics {
                id: undoHeadingMetrics
                font: undoHeading.font
                text: undoHeading.text
            }
            UI.ActionButton {
                id: undoAllButton
                objectName: "undoAllTwitchUsers"
                anchors.right: parent.right
                width: implicitContentWidth
                height: Theme.twitchEditorHeight
                label: "Undo all (" + TwitchService.removedUsers.length + ")"
                hint: "Restore all recently removed streamers"
                fillColor: Theme.accent
                enabled: TwitchService.usersReady
                onClicked: TwitchService.undoAllRemovals()
            }
        }

        TwitchActionGrid {
            id: undoView
            objectName: "twitchUndoGrid"
            width: root.width
            height: root.undoHeight
            visible: root.hasUndo
            logins: TwitchService.removedUsers.map(entry => entry.login)
            glyph: Theme.retryIcon
            hintPrefix: "Restore "
            buttonPrefix: "undoRemoveTwitchUser_"
            enabled: TwitchService.usersReady
            onSelected: login => TwitchService.undoRemoveUser(login)
        }

        Text {
            id: errorText
            width: root.width
            height: Math.min(implicitHeight, root.maximumHeight * 0.2)
            visible: text.length > 0
            text: TwitchService.error
            color: Theme.warning
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            clip: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            UI.HoverTooltip { text: TwitchService.error }
        }
    }
}
