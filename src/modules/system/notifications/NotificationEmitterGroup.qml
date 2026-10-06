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
        return NotificationRepository.entries(group.emitterKey, expanded ? entryLimit : 1, 0)
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
            hint: "Delete this emitter's history and dismiss its current notifications; keep its settings"
            onClicked: NotificationService.clearEmitter(root.group.emitterKey)
        }
    }
    Repeater {
        model: root.entries
        NotificationCard { required property var modelData; width: root.width; entry: modelData }
    }
    NotificationButton {
        visible: root.expanded && root.entries.length < root.group.count
        label: "Load older notifications"
        onClicked: root.loadMore()
    }
}
