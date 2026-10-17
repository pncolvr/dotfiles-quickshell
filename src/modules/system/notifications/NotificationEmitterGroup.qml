pragma ComponentBehavior: Bound

import "../../../i18n"
import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import "../../../theme"
import "../../../ui" as UI
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
    UI.BatchedListModel { id: historyModel; items: root.entries }
    spacing: 8
    RowLayout {
        width: parent.width
        spacing: Theme.controlSpacing
        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: countLabel.implicitWidth + expandIcon.width + 16
            Layout.preferredHeight: Theme.controlHeight
            UI.IconText {
                id: expandIcon
                anchors.left: parent.left
                visible: root.group.count > 1
                width: visible ? 16 : 0
                text: root.expanded ? Theme.chevronDownIcon : Theme.chevronRightIcon
                horizontalAlignment: Text.AlignHCenter
                color: Theme.inactive
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
            QC.AbstractButton {
                id: groupToggle
                anchors.fill: parent
                enabled: root.group.count > 1
                Accessible.name: root.emitter?.name || root.group.emitterKey
                background: Rectangle { color: "transparent"; radius: Theme.iconButtonRadius; border.width: groupToggle.visualFocus ? 1 : 0; border.color: Theme.accent }
                UI.FocusReveal { owner: groupToggle }
                HoverHandler { cursorShape: groupToggle.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
                onClicked: root.toggleExpanded()
                Keys.onReturnPressed: click()
                Keys.onEnterPressed: click()
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
            hint: Translations.text("notifications.actions.clearEmitterHint")
            onClicked: NotificationService.clearEmitter(root.group.emitterKey)
        }
    }
    Column {
        id: cards
        width: root.width
        spacing: root.expanded ? root.spacing : 0
        Repeater {
            model: historyModel
            Item {
                id: historyEntry
                required property var value
                required property int index
                readonly property bool stacked: !root.expanded && index > 0
                readonly property real cardInset: stacked ? index * Theme.notificationStackInset : 0
                width: cards.width
                implicitHeight: stacked ? Theme.notificationStackPeekHeight : historyCard.implicitHeight
                clip: stacked

                NotificationCard {
                    id: historyCard
                    entry: historyEntry.value
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
        label: Translations.text("notifications.actions.loadOlder")
        onClicked: root.loadMore()
    }
}
