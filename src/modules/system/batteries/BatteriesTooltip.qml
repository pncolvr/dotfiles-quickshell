pragma ComponentBehavior: Bound

import "../../../i18n"
import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../../theme"
import "../../../ui" as UI
import "../../../services"

Column {
    id: root
    readonly property bool footerInGutter: true
    property var batteries: BatteryService.batteries
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxListHeight: (monitor?.height ?? 1080) * Theme.batteryTooltipMaxHeightRatio
    width: Math.min(Theme.batteryTooltipWidth, (monitor?.width ?? Theme.batteryTooltipWidth + Theme.tooltipPaddingWidth * 2) - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.batterySpacing

    UI.ColumnText {
        width: parent.width
        visible: BatteryService.scanningReceivers && root.batteries.length === 0
        text: Translations.text("batteries.status.checking")
        color: Theme.inactive
    }

    UI.EmptyState {
        visible: root.batteries.length === 0 && !BatteryService.scanningReceivers
        text: Translations.text("batteries.empty")
    }

    ListView {
        id: list
        property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: list }
        objectName: "batteryList"
        width: root.width + Theme.scrollbarGutter
        height: Math.min(contentHeight, root.maxListHeight)
        spacing: Theme.batterySpacing
        model: root.batteries
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        delegate: BatteryRow {
            required property var modelData
            battery: modelData
            width: root.width
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
    }
    UI.PanelFooter { objectName: "batteriesFooter"; width: root.width; message: BatteryService.receiverError }
}
