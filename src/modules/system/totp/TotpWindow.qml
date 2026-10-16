import QtQuick
import "../../../bar"
import "../../../theme"
import "../../../services"

PrivateTooltipWindow {
    id: root
    requestedVisible: TooltipService.visible && TooltipService.source?.totpModule === true && !!targetScreen
    contentWidth: keys.implicitWidth + Theme.tooltipPaddingWidth * 2
    contentHeight: keys.implicitHeight + Theme.tooltipPaddingHeight * 2
    readonly property var loadedContent: keys.loadedContent
    focusPanel: keys
    TooltipContent { id: keys; host: root; anchors.fill: parent }
}
