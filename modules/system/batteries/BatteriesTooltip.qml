pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Column {
    id: root
    property var batteries: BatteryService.batteries
    readonly property var monitor: TooltipService.screen ?? root.QsWindow.window?.screen
    readonly property real maxListHeight: (monitor?.height ?? 1080) * Theme.batteryTooltipMaxHeightRatio
    width: Math.min(Theme.batteryTooltipWidth, (monitor?.width ?? Theme.batteryTooltipWidth + Theme.tooltipPaddingWidth * 2) - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.batterySpacing

    UI.ColumnText {
        width: parent.width
        visible: BatteryService.scanningReceivers && root.batteries.length === 0
        text: "Checking device batteries…"
        color: Theme.inactive
    }

    UI.ColumnText {
        width: parent.width
        visible: BatteryService.receiverError.length > 0
        text: BatteryService.receiverError
        wrapMode: Text.Wrap
        color: Theme.warning
    }

    UI.ColumnText {
        width: parent.width
        visible: root.batteries.length === 0 && !BatteryService.scanningReceivers
        text: "No batteries detected"
        color: Theme.inactive
    }

    ListView {
        id: list
        objectName: "batteryList"
        width: parent.width
        height: Math.min(contentHeight, root.maxListHeight)
        spacing: Theme.batterySpacing
        model: root.batteries
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        delegate: BatteryRow {
            required property var modelData
            battery: modelData
            width: list.width - (scrollbar.visible ? Theme.batteryScrollbarWidth + Theme.batteryScrollbarMargin : 0)
        }
        QC.ScrollBar.vertical: QC.ScrollBar {
            id: scrollbar
            implicitWidth: Theme.batteryScrollbarWidth
            visible: list.contentHeight > list.height
            policy: QC.ScrollBar.AsNeeded
            contentItem: Rectangle {
                radius: width / 2
                color: Theme.accent
                opacity: scrollbar.active ? 1 : 0.5
            }
            background: Rectangle { color: Theme.empty; radius: width / 2 }
        }
    }
}
