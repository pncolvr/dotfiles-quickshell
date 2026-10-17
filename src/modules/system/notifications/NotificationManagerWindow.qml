pragma ComponentBehavior: Bound

import "../../../i18n"
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
    requestedVisible: TooltipService.visible && TooltipService.source?.notificationsModule === true && !!targetScreen
    onRequestedVisibleChanged: {
        if (!requestedVisible && settings) settings.clearSearch()
        else if (requestedVisible) Qt.callLater(root.requestPanelFocus)
    }
    contentWidth: Math.max(1, Math.min(Theme.notificationManagerWidth, targetScreen?.width || 560))
    contentHeight: Math.min(720, Math.max(1, (targetScreen?.height || 1080) - Theme.barHeight - 20),
        header.height + (tab === "History" ? history.implicitHeight : settings.implicitHeight)
            + Theme.tooltipPaddingHeight * 2 + 12)

    focusPanel: content
    UI.PanelFocusScope {
        id: content
        onDismissRequested: TooltipService.dismiss()
        anchors.fill: parent
        Column {
            id: header
            x: Theme.tooltipPaddingWidth; y: Theme.tooltipPaddingHeight
            width: parent.width - Theme.tooltipPaddingWidth * 2
            spacing: 8
            Item {
                width: parent.width
                height: Theme.controlHeight
                UI.TabBar {
                    id: tabs
                    objectName: "notificationTabs"
                    labels: [Translations.text("notifications.tabs.history"), Translations.text("notifications.tabs.emitters")]
                    anchors.left: parent.left
                    anchors.right: actions.left
                    anchors.rightMargin: Theme.controlSpacing
                    height: parent.height
                }
                Row {
                    id: actions
                    anchors.right: parent.right
                    spacing: Theme.controlSpacing
                    UI.ActionButton {
                        keyAction: "notifications.dnd"
                        glyph: NotificationService.dndEnabled ? Theme.notificationsDndEnabledIcon : Theme.notificationsDndDisabledIcon
                        foreground: NotificationService.dndEnabled ? Theme.accent : Theme.text
                        hint: Translations.text(NotificationService.dndEnabled ? "notifications.dnd.disableHint" : "notifications.dnd.enableHint")
                        onClicked: NotificationService.toggle()
                    }
                    UI.ActionButton {
                        glyph: Theme.clearIcon
                        fillColor: Theme.urgent
                        hint: Translations.text("notifications.actions.clearAllHint")
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
            QC.ScrollBar.vertical: UI.ScrollBar {}
            Column {
                id: history
                width: historyView.width - 10
                spacing: 16
                UI.Text { centerVertical: false; visible: !root.groups.length; text: Translations.text("notifications.empty.history") }
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
                NotificationButton { visible: root.groups.length > root.groupLimit; label: Translations.text("notifications.actions.loadOlderEmitters"); onClicked: root.groupLimit += Config.notificationPageSize }
            }
        }
        NotificationEmitterSettings {
            id: settings
            x: historyView.x; y: historyView.y
            width: historyView.width; height: historyView.height
            visible: root.tab === "Emitters"
        }
    }
}
