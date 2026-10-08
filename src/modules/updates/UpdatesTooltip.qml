pragma ComponentBehavior: Bound

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

        UI.ColumnText {
            visible: UpdatesService.hasUpdates
            text: `${UpdatesService.count} updates available`
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.text

            UI.HoverTooltip {
                cursorShape: Qt.PointingHandCursor
                text: "open all updates"
                onClicked: UpdatesService.openMarkdown()
            }
        }

        UI.ColumnText {
            visible: UpdatesService.hasUpdates
            text: `last checked ${Qt.formatTime(UpdatesService.lastChecked, "HH:mm")}`
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.inactive
        }

        Rectangle {
            visible: UpdatesService.hasUpdates
            width: parent.width
            height: 1
            color: Theme.empty
        }

        UI.ColumnText {
            visible: !UpdatesService.hasUpdates && !UpdatesService.error
            text: "no updates available"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.inactive
        }

        UI.ColumnText {
            visible: !UpdatesService.hasUpdates
            text: `last checked ${Qt.formatTime(UpdatesService.lastChecked, "HH:mm")}`
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.inactive
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
