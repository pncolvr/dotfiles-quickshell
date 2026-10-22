import QtQuick
import "../../../ui/panels"
import "../../../theme"
import "../../../services"

PrivateTooltipWindow {
    id: root
    requestedVisible: TooltipService.visible && TooltipService.source?.totpModule === true && !!targetScreen
    contentWidth: keys.implicitWidth + Theme.tooltipPaddingWidth * 2
    contentHeight: keys.implicitHeight + Theme.tooltipPaddingHeight + Theme.tooltipPaddingWidth
    readonly property var loadedContent: keys.loadedContent
    focusPanel: keys
    TooltipContent { id: keys; host: root; anchors.fill: parent }
}
