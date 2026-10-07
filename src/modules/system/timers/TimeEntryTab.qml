import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Column {
    id: root
    property Component creationComponent: null
    property alias listContent: entries.data
    property bool empty: true
    property string emptyMessage: ""
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxListHeight: Math.max(Theme.controlHeight,
        (monitor?.height ?? 1080) * Theme.timersMaxHeightRatio - Theme.controlHeight - creator.height - spacing * 3 - 1)
    spacing: Theme.controlSpacing

    Loader {
        id: creator
        width: root.width
        sourceComponent: root.creationComponent
    }
    Rectangle { width: root.width; height: 1; color: Theme.empty }
    Flickable {
        id: list
        objectName: "timerList"
        width: root.width
        height: Math.min(contentHeight, root.maxListHeight)
        contentHeight: entries.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QC.ScrollBar.vertical: UI.ScrollBar {}

        Column {
            id: entries
            width: list.width
            spacing: Theme.controlSpacing
            UI.Text {
                centerVertical: false
                visible: root.empty
                text: root.emptyMessage
                color: Theme.inactive
            }
        }
    }
}
