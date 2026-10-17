pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../ui" as UI

QC.ScrollView {
    id: root
    property var logins: []
    property string glyph: Theme.addIcon
    property string hintKey: "twitch.actions.addChannel"
    property string buttonPrefix: "addBrowserTwitchUser_"
    property string gridObjectName: ""
    readonly property real gridHeight: grid.implicitHeight
    signal selected(string login)
    clip: true
    contentWidth: width
    contentHeight: grid.implicitHeight
    QC.ScrollBar.horizontal.policy: QC.ScrollBar.AlwaysOff
    QC.ScrollBar.vertical: UI.ScrollBar {}
    Grid {
        id: grid
        objectName: root.gridObjectName
        width: root.contentWidth
        columns: Math.min(3, Math.max(1, root.logins.length), Math.max(1,
            Math.floor((root.width + Theme.twitchTooltipSpacing) / (Theme.twitchSuggestionMinWidth + Theme.twitchTooltipSpacing))))
        spacing: Theme.twitchTooltipSpacing
        Repeater {
            model: root.logins
            delegate: UI.ActionButton {
                required property string modelData
                objectName: root.buttonPrefix + modelData
                width: (grid.width - (grid.columns - 1) * grid.spacing) / grid.columns
                height: Theme.twitchEditorHeight
                label: modelData
                glyph: root.glyph
                hint: Translations.text(root.hintKey,[modelData])
                enabled: root.enabled
                onClicked: root.selected(modelData)
            }
        }
    }
}
