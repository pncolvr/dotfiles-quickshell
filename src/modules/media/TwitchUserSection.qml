pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI

Column {
    id: root
    required property string title
    required property var users
    required property int columns
    property bool expanded: true
    property bool forceExpanded: false
    readonly property bool showingUsers: expanded || forceExpanded
    spacing: Theme.twitchTooltipSpacing
    visible: users.length > 0

    QC.Button {
        id: heading
        objectName: "toggleTwitchUserSection"
        width: parent.width
        implicitHeight: Math.max(label.implicitHeight, arrow.implicitHeight)
        padding: 0
        hoverEnabled: true
        checkable: !root.forceExpanded
        checked: root.showingUsers
        Accessible.name: root.title + " (" + root.users.length + "), "
            + (root.forceExpanded ? "search results" : root.expanded ? "collapse" : "expand")
        onClicked: if (!root.forceExpanded) root.expanded = !root.expanded

        background: Rectangle {
            radius: Theme.iconButtonRadius
            color: heading.hovered || heading.activeFocus ? Theme.alternateBackground : "transparent"
        }
        contentItem: Item {
            UI.IconText {
                id: arrow
                anchors.left: parent.left
                text: Theme.chevronDownIcon
                rotation: root.showingUsers ? 0 : -90
                color: Theme.inactive
            }
            UI.ColumnText {
                id: label
                anchors.left: arrow.right
                anchors.leftMargin: Theme.controlSpacing
                text: root.title + " (" + root.users.length + ")"
                color: Theme.inactive
                centerVertical: true
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    Grid {
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
            }
        }
    }
}
