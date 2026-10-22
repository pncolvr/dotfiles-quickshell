pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui" as UI

Column {
    id: root
    required property string title
    required property var users
    required property int columns
    property bool expanded: true
    property bool forceExpanded: false
    signal editRequested(string login)
    readonly property bool showingUsers: heading.showingContent
    property alias contentItem: grid
    spacing: Theme.twitchTooltipSpacing
    visible: users.length > 0

    UI.CollapsibleSection {
        id: heading
        objectName: "toggleTwitchUserSection"
        width: root.width
        implicitHeight: label.implicitHeight
        padding: 0
        expanded: root.expanded
        forceExpanded: root.forceExpanded
        onExpansionRequested: expanded => root.expanded = expanded
        Accessible.name: root.title + " (" + root.users.length + "), "
            + (root.forceExpanded ? Translations.text("twitch.sections.searchResults")
                : Translations.text(root.expanded ? "common.actions.collapse" : "common.actions.expand"))
        contentItem: UI.ColumnText {
            id: label
            text: root.title + " (" + root.users.length + ")"
            color: Theme.inactive
            centerVertical: false
        }
    }
    Grid {
        id: grid
        objectName: "twitchUserSectionGrid"
        width: root.width
        visible: root.showingUsers
        columns: root.columns
        spacing: Theme.twitchTooltipSpacing
        verticalItemAlignment: Grid.AlignVCenter
        Repeater {
            model: root.users
            delegate: TwitchUserRow {
                required property var modelData
                width: root.width
                user: modelData
                onEditRequested: login => root.editRequested(login)
            }
        }
    }
}
