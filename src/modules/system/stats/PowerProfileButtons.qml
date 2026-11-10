pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import "../../../theme"
import "../../../ui" as UI
import "../../../services"
import "../../../config"

// Compact glyph-only profile switcher; labels live in the hover hint.
Row {
    id: root
    property var powerService: PowerProfileService
    spacing: 2
    Repeater {
        model: Config.powerProfiles
        UI.ActionButton {
            required property string modelData
            required property int index
            objectName: "statsPowerProfile-" + modelData
            width: Theme.statsPowerProfileButtonSize
            height: Theme.statsPowerProfileButtonSize
            anchors.verticalCenter: parent.verticalCenter
            readonly property string profileName: [Translations.text("stats.power.saver"), Translations.text("stats.power.balanced"), Translations.text("stats.power.performance")][index]
            glyph: Theme.powerProfileIcons[index]
            hint: enabled ? profileName : Translations.text("common.states.unavailableLabel",[profileName])
            enabled: root.powerService.availableProfiles.includes(modelData)
            checked: root.powerService.profile === modelData
            foreground: checked ? Theme.accent : Theme.inactive
            fillColor: checked ? Theme.selectionSelectedBackground : Theme.controlFill
            onClicked: root.powerService.setProfile(modelData)
        }
    }
}
