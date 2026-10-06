pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Column {
    id: root
    required property var group
    property bool expanded: false
    property int entryLimit: 25
    signal toggleExpanded()
    signal loadMore()
    readonly property var emitter: NotificationEmitterRepository.emitters[group.emitterKey]
    readonly property var entries: {
        const revision = NotificationRepository.revision
        return NotificationRepository.entries(group.emitterKey,
            expanded ? entryLimit : Theme.notificationStackMaxCards, 0)
    }
    spacing: 8
    RowLayout {
        width: parent.width
        spacing: Theme.controlSpacing
        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: countLabel.implicitWidth + expandIcon.width + 16
            Layout.preferredHeight: Theme.controlHeight
            UI.Text {
                id: expandIcon
                anchors.left: parent.left
                visible: root.group.count > 1
                width: visible ? 16 : 0
                text: root.expanded ? "-" : "+"
                horizontalAlignment: Text.AlignHCenter
            }
            UI.Text {
                id: countLabel
                anchors.left: expandIcon.right
                anchors.leftMargin: expandIcon.visible ? 4 : 0
                text: root.group.count
                textFormat: Text.PlainText
            }
            UI.Text {
                anchors.left: countLabel.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                text: root.emitter?.name || root.group.emitterKey
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.group.count > 1
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleExpanded()
            }
        }
        NotificationSourceControls {
            emitterKey: root.group.emitterKey
            Layout.preferredWidth: naturalWidth
        }
        NotificationButton {
            implicitWidth: Theme.controlHeight
            glyph: Theme.deleteIcon
            fillColor: Theme.notificationCritical
            hint: "Delete this emitter's history and dismiss its current notifications; keep its settings"
            onClicked: NotificationService.clearEmitter(root.group.emitterKey)
        }
    }
    Column {
        id: cards
        width: root.width
        spacing: root.expanded ? root.spacing : 0
        Repeater {
            model: root.entries
            Item {
                id: historyEntry
                required property var modelData
                required property int index
                readonly property bool stacked: !root.expanded && index > 0
                readonly property real cardInset: stacked ? index * Theme.notificationStackInset : 0
                width: cards.width
                implicitHeight: stacked ? Theme.notificationStackPeekHeight : historyCard.implicitHeight
                clip: stacked

                NotificationCard {
                    id: historyCard
                    entry: historyEntry.modelData
                    x: historyEntry.cardInset
                    y: historyEntry.stacked ? historyEntry.height - height : 0
                    width: Math.max(0, historyEntry.width - historyEntry.cardInset * 2)
                    enabled: !historyEntry.stacked
                }
                MouseArea {
                    anchors.fill: parent
                    visible: historyEntry.stacked
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleExpanded()
                }
            }
        }
    }
    NotificationButton {
        visible: root.expanded && root.entries.length < root.group.count
        label: "Load older notifications"
        onClicked: root.loadMore()
    }
}
