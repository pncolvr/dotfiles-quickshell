import QtQuick

import "../../theme"
import "../../theme/ui" as UI
import "../../services"

UI.TooltipArea {
    moduleName: "status"
    id: root
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    tooltipSource: root
    readonly property bool tooltipKeyboardFocus: true
    tooltip: Component { StatusTooltip {} }
    function statusToIcon(status) {
        switch (status) {
            case "personal": return Theme.statusPersonalIcon
            case "work": return Theme.statusWorkingIcon
            default: return Theme.statusUnknownIcon
        }
    }

    UI.IconText {
        color: TooltipService.pinned && TooltipService.source === root ? Theme.accent
            : StatusService.source === "manual" ? Theme.warning : Theme.text
        text: root.statusToIcon(StatusService.status)
    }

    onClicked: mouse => {
        if (mouse.button !== Qt.LeftButton) return
        const pos = root.mapToGlobal(root.width / 2, 0)
        TooltipService.togglePin(pos.x, tooltip, root, centerTooltip, tooltipScreen)
    }
}
