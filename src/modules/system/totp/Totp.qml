import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

UI.TooltipArea {
    id: root
    moduleName: "totp"
    moduleFocusSearch: true
    required property var window
    readonly property bool totpModule: true
    readonly property bool tooltipKeyboardFocus: true
    ownsTooltipWindow: true
    tooltipSource: root
    tooltipScreen: window.screen
    tooltip: Component { TotpTooltip {} }
    onClicked: {
        const pos = root.mapToGlobal(root.width / 2, 0)
        TooltipService.togglePin(pos.x, tooltip, root, centerTooltip, tooltipScreen)
    }

    UI.IconText {
        text: Theme.totpIcon
        color: TooltipService.pinned && TooltipService.source === root ? Theme.accent : Theme.text
    }
}
