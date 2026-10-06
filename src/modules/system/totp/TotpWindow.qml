import QtQuick
import "../../../bar"
import "../../../theme"
import "../../../services"

PrivateTooltipWindow {
    id: root
    visible: TooltipService.visible && TooltipService.source?.totpModule === true && !!targetScreen
    contentWidth: loader.implicitWidth + Theme.tooltipPaddingWidth * 2
    contentHeight: loader.implicitHeight + Theme.tooltipPaddingHeight * 2

    Loader {
        id: loader
        active: root.visible
        anchors.centerIn: parent
        sourceComponent: TooltipService.content
    }
}
