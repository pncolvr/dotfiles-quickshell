pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../theme/ui" as UI
import "../../theme"
import "../../services"

Column {
    id: root
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxPanelHeight: Math.max(0, Math.min((monitor?.height ?? 1080) * Theme.updatesTooltipMaxHeightRatio,
        (monitor?.height ?? 1080) - Theme.barHeight - Theme.tooltipPaddingHeight * 2))
    width: Math.min(Theme.updatesTooltipWidth, (monitor?.width ?? Theme.updatesTooltipWidth + Theme.tooltipPaddingWidth * 2)
        - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.controlSpacing

    Column {
        id: header
        width: parent.width
        spacing: root.spacing
        UI.ColumnText {
            visible: UpdatesService.error.length > 0
            text: UpdatesService.error
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.warning
        }

        Item {
            width: parent.width
            height: Math.max(summary.implicitHeight, actions.implicitHeight)
            Column {
                id: summary
                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: Theme.controlSpacing
                spacing: 0
                UI.ColumnText {
                    width: parent.width
                    text: UpdatesService.hasUpdates ? Translations.text("updates.status.available",[],UpdatesService.count) : Translations.text("updates.empty")
                    color: UpdatesService.hasUpdates ? Theme.text : Theme.inactive
                }
                UI.ColumnText {
                    width: parent.width
                    text: Translations.text("updates.status.lastChecked",[Qt.formatTime(UpdatesService.lastChecked, "HH:mm")])
                    color: Theme.inactive
                }
            }
            Row {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.controlSpacing
                UI.ActionButton {
                    objectName: "updatesNotes"
                    glyph: Theme.notesIcon
                    hint: Translations.text("updates.actions.notesHint")
                    enabled: UpdatesService.hasUpdates
                    onClicked: UpdatesService.openMarkdown()
                }
                UI.ActionButton {
                    objectName: "updatesCheckNow"
                    keyAction: "refresh"
                    glyph: Theme.refreshIcon
                    hint: Translations.text("updates.actions.checkNowHint")
                    enabled: !UpdatesService.checking
                    onClicked: UpdatesService.checkNow()
                }
                UI.ActionButton {
                    objectName: "updatesInstall"
                    glyph: Theme.downloadIcon
                    hint: Translations.text("updates.actions.installHint")
                    enabled: UpdatesService.hasUpdates
                    onClicked: UpdatesService.install()
                }
            }
        }
        Rectangle {
            visible: UpdatesService.hasUpdates
            width: parent.width
            height: 1
            color: Theme.empty
        }
    }

    Flickable {
        id: list
        objectName: "updatesList"
        width: parent.width
        height: Math.min(contentHeight, Math.max(0, root.maxPanelHeight - header.height - root.spacing))
        contentWidth: width
        contentHeight: entries.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: entries
            width: list.width
            spacing: root.spacing
            Repeater {
                model: UpdatesService.priorityUpdates
                delegate: UpdateRow {
                    required property var modelData
                    update: modelData
                    nameColor: Theme.warning
                }
            }

            Rectangle {
                visible: UpdatesService.priorityUpdates.length > 0 && UpdatesService.normalUpdates.length > 0
                width: parent.width
                height: 1
                color: Theme.empty
            }

            Repeater {
                model: UpdatesService.normalUpdates
                delegate: UpdateRow {
                    required property var modelData
                    update: modelData
                    nameColor: Theme.text
                }
            }
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
    }
}
