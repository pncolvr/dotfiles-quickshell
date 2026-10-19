import QtQuick
import "../../../theme"
import "../../../ui" as UI
import "../../../config"
import "../../../services"

UI.TooltipArea {
    moduleName: "files"
    id: root
    required property var window
    visible: Config.recentFilesEnabled
    enabled: visible
    onVisibleChanged: if (!visible && TooltipService.source === root) TooltipService.dismiss()

    tooltipSource: root
    tooltipScreen: window.screen
    tooltip: Component { RecentFilesTooltip {} }

    UI.BarIcon {
        objectName: "recentFilesBarIcon"
        text: Theme.recentFilesIcon
        color: root.moduleIconColor
    }
}
