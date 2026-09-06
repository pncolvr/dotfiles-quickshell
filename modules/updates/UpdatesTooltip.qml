pragma ComponentBehavior: Bound

import QtQuick
import "../../theme/ui" as UI
import "../../theme"
import "../../services"
import "../../config"

Column {
    width: Theme.updatesTooltipWidth
    spacing: 4

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

    Rectangle {
        visible: UpdatesService.hasUpdates
        width: parent.width
        height: 1
        color: Theme.empty
    }

    UI.ColumnText {
        visible: !UpdatesService.hasUpdates
        text: "no updates available"
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        color: Theme.inactive
    }

    Repeater {
        model: UpdatesService.priorityUpdates.slice(0, Config.updatesMax)
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
        model: UpdatesService.normalUpdates.slice(0, Math.max(0, Config.updatesMax - UpdatesService.priorityUpdates.length))
        delegate: UpdateRow {
            required property var modelData
            update: modelData
            nameColor: Theme.text
        }
    }

    UI.ColumnText {
        visible: UpdatesService.count > Config.updatesMax
        text: `… and ${UpdatesService.count - Config.updatesMax} more`
        color: Theme.inactive
    }
}