pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../../bar"
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../config"
import "../../../services"

PrivateTooltipWindow {
    id: root
    readonly property string tab: tabs.currentIndex === 0 ? "History" : "Emitters"
    property int groupLimit: Config.notificationPageSize
    property var expandedEmitters: ({})
    property var entryLimits: ({})
    readonly property Item previewItem: content.parent
    readonly property var groups: {
        const revision = NotificationRepository.revision
        return NotificationRepository.groups(groupLimit + 1, 0)
    }
    visible: TooltipService.visible && TooltipService.source?.notificationsModule === true && !!targetScreen
    contentWidth: Math.max(1, Math.min(Theme.notificationManagerWidth, targetScreen?.width || 560))
    contentHeight: Math.min(720, Math.max(1, (targetScreen?.height || 1080) - Theme.barHeight - 20),
        header.height + (tab === "History" ? history.implicitHeight : settings.implicitHeight)
            + Theme.tooltipPaddingHeight * 2 + 12)

    Item {
        id: content
        anchors.fill: parent
        Column {
            id: header
            x: Theme.tooltipPaddingWidth; y: Theme.tooltipPaddingHeight
            width: parent.width - Theme.tooltipPaddingWidth * 2
            spacing: 8
            Item {
                width: parent.width
                height: Theme.controlHeight
                QC.TabBar {
                    id: tabs
                    anchors.left: parent.left
                    anchors.right: actions.left
                    anchors.rightMargin: Theme.controlSpacing
                    height: parent.height
                    background: Rectangle {
                        color: "transparent"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.empty }
                    }
                    Repeater {
                        model: ["History", "Emitters"]
                        QC.TabButton {
                            id: tabButton
                            required property string modelData
                            text: modelData
                            width: implicitWidth
                            implicitWidth: tabLabel.implicitWidth + Theme.controlFieldPadding * 4
                            implicitHeight: Theme.controlHeight
                            padding: 0
                            hoverEnabled: true
                            contentItem: UI.Text {
                                id: tabLabel
                                centerVertical: false
                                text: tabButton.text
                                color: tabButton.checked ? Theme.accent : Theme.inactive
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: tabButton.down ? Qt.darker(Theme.alternateBackground, 1.2)
                                    : tabButton.hovered ? Theme.alternateBackground : "transparent"
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 2
                                    visible: tabButton.checked
                                    color: Theme.accent
                                }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
                Row {
                    id: actions
                    anchors.right: parent.right
                    spacing: Theme.controlSpacing
                    NotificationButton {
                        label: NotificationService.dndEnabled ? "DND on" : "DND off"
                        foreground: NotificationService.dndEnabled ? Theme.accent : Theme.text
                        hint: "Toggle do not disturb; only whitelisted emitters bypass it"
                        onClicked: NotificationService.toggle()
                    }
                    NotificationButton {
                        label: "Clear all"
                        hint: "Delete all saved history and dismiss current notifications; keep emitter settings and DND"
                        onClicked: NotificationService.clearAll()
                    }
                }
            }
            UI.Text {
                centerVertical: false
                width: parent.width
                visible: text.length > 0
                text: NotificationService.error || NotificationService.focusMessage
                color: Theme.warning
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
        }
        Flickable {
            id: historyView
            x: Theme.tooltipPaddingWidth
            y: header.y + header.height + 12
            width: parent.width - Theme.tooltipPaddingWidth * 2
            height: Math.max(0, parent.height - y - Theme.tooltipPaddingHeight)
            visible: root.tab === "History"
            clip: true
            contentWidth: width
            contentHeight: history.height
            boundsBehavior: Flickable.StopAtBounds
            QC.ScrollBar.vertical: QC.ScrollBar { HoverHandler { cursorShape: Qt.PointingHandCursor } }
            Column {
                id: history
                width: historyView.width - 10
                spacing: 16
                UI.Text { centerVertical: false; visible: !root.groups.length; text: "No saved notifications." }
                Repeater {
                    model: root.groups.slice(0, root.groupLimit)
                    NotificationEmitterGroup {
                        required property var modelData
                        width: history.width
                        group: modelData
                        expanded: !!root.expandedEmitters[modelData.emitterKey]
                        entryLimit: root.entryLimits[modelData.emitterKey] || Config.notificationPageSize
                        onToggleExpanded: root.expandedEmitters = Object.assign({}, root.expandedEmitters, {[modelData.emitterKey]: !expanded})
                        onLoadMore: root.entryLimits = Object.assign({}, root.entryLimits, {[modelData.emitterKey]: entryLimit + Config.notificationPageSize})
                    }
                }
                NotificationButton { visible: root.groups.length > root.groupLimit; label: "Load older emitters"; onClicked: root.groupLimit += Config.notificationPageSize }
            }
        }
        Flickable {
            id: emitterView
            x: historyView.x; y: historyView.y
            width: historyView.width; height: historyView.height
            visible: root.tab === "Emitters"
            clip: true
            contentWidth: width
            contentHeight: settings.height
            boundsBehavior: Flickable.StopAtBounds
            QC.ScrollBar.vertical: QC.ScrollBar { HoverHandler { cursorShape: Qt.PointingHandCursor } }
            NotificationEmitterSettings { id: settings; width: emitterView.width - 10 }
        }
    }
}
