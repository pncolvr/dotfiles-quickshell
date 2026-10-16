import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI

UI.TooltipArea {
    moduleName: "files"
    id: root
    required property var window

    tooltipSource: root
    tooltipScreen: window.screen
    tooltip: Component { RecentFilesTooltip {} }

    UI.BarIcon {
        objectName: "recentFilesBarIcon"
        text: Theme.recentFilesIcon
        color: root.moduleIconColor
    }
}
