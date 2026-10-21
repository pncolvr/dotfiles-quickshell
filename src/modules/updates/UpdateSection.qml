pragma ComponentBehavior: Bound
import QtQuick
import "../../ui" as UI
import "../../theme"
import "../../i18n"

Column {
    id: section
    required property var updates
    required property color nameColor
    property bool expanded: true
    property bool forceExpanded: false
    readonly property bool showingContent: heading.showingContent
    property alias contentItem: rows
    width: parent.width
    visible: updates.length > 0
    spacing: Theme.controlSpacing

    UI.CollapsibleSection {
        id: heading
        objectName: section.objectName + "Toggle"
        width: section.width
        implicitHeight: countLabel.implicitHeight
        padding: 0
        chevronColor: Theme.text
        expanded: section.expanded
        forceExpanded: section.forceExpanded
        onExpansionRequested: expanded => section.expanded = expanded
        Accessible.name: String(section.updates.length) + ", "
            + Translations.text(showingContent ? "common.actions.collapse" : "common.actions.expand")
        background: Rectangle {
            radius: Theme.iconButtonRadius
            color: heading.hovered || heading.keyboardFocusVisible ? Theme.alternateBackground : "transparent"
        }
        contentItem: Item {
            Rectangle {
                anchors.left: parent.left
                anchors.right: countLabel.left
                anchors.rightMargin: Theme.controlSpacing
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Theme.empty
            }
            UI.ColumnText {
                id: countLabel
                objectName: section.objectName + "Count"
                anchors.right: parent.right
                text: String(section.updates.length)
                color: section.nameColor
            }
        }
    }
    Column {
        id: rows
        width: section.width
        spacing: section.spacing
        visible: section.showingContent
        Repeater {
            model: section.updates
            delegate: UpdateRow {
                required property var modelData
                update: modelData
                nameColor: section.nameColor
            }
        }
    }
}
