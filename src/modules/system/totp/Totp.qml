import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../config"

UI.TooltipArea {
    id: root
    moduleName: "totp"
    required property var window
    readonly property bool totpModule: true
    visible: Config.totpEnabled

    ownsTooltipWindow: true
    tooltipSource: root
    tooltipScreen: window.screen
    tooltip: Component { TotpTooltip {} }


    UI.BarIcon {
        text: Theme.totpIcon
        color: root.moduleIconColor
    }
}
