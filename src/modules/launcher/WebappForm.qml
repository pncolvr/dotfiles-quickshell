pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../theme"
import "../../theme/ui" as UI
import "../../services/launcher/CommandArguments.mjs" as Arguments

Column {
    id: root
    property var original: ({})
    property alias browser: browserFields.browser
    property alias browserProfile: browserFields.browserProfile
    property alias windowMode: browserFields.windowMode
    property string entryCategory: 'personal'
    property bool entryEnabled: true
    property bool advanced: false
    property string parseError: ''
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { name.focusInput() }
    function load(entry) {
        original=entry; name.text=entry.name; url.text=entry.url; browser=entry.browser; browserProfile=entry.profile
        windowMode=entry.windowMode; entryEnabled=entry.enabled; entryCategory=entry.category || 'personal'
        extra.text=Arguments.join(entry.arguments); before.text=Arguments.join(entry.before); after.text=Arguments.join(entry.after)
        advanced=false; parseError=''
    }
    function value() {
        parseError=''
        try {
            return Object.assign({},original,{name:name.text,url:url.text,browser,profile:browserProfile,windowMode,
                enabled:entryEnabled,category:entryCategory,arguments:Arguments.split(extra.text),
                before:Arguments.command(before.text),after:Arguments.command(after.text)})
        } catch (error) { parseError=Translations.message(error); return null }
    }
    UI.LabeledField { onAccepted: root.accepted(); id: name; inputObjectName:'webappName'; width: parent.width; label:Translations.text("common.fields.name") }
    UI.LabeledField { onAccepted: root.accepted(); id: url; inputObjectName:'webappUrl'; width: parent.width; label:Translations.text("common.fields.url"); placeholderText:'https://example.com' }
    BrowserLaunchFields { id:browserFields; width:parent.width }
    EntryCategorySelector {
        objectName:'webappCategorySelector'
        toggleObjectName:'webappCategoryToggle'
        choicesObjectName:'webappCategoryChoices'
        width: parent.width
        selectedName:root.entryCategory
        onSelected: name => root.entryCategory=name
    }
    UI.ActionButton {
        objectName:'webappEnabled'
        label: Translations.text(root.entryEnabled ? "common.states.enabled" : "common.states.disabled")
        checkable:true; checked:root.entryEnabled
        foreground: root.entryEnabled ? Theme.accent : Theme.inactive
        hint: Translations.text("webapps.fields.enabledHint")
        onClicked: root.entryEnabled=!root.entryEnabled
    }
    UI.ActionButton {
        objectName:'webappAdvanced'
        label:Translations.text("common.sections.advanced"); glyph:Theme.chevronDownIcon
        checkable:true; checked:root.advanced
        foreground: root.advanced ? Theme.accent : Theme.text
        hint: Translations.text("webapps.advanced.hint")
        onClicked: root.advanced=!root.advanced
    }
    Column {
        width: parent.width; spacing:Theme.controlSpacing; visible:root.advanced
        UI.LabeledField { onAccepted: root.accepted(); id:extra; width:parent.width; label:Translations.text("webapps.fields.arguments") }
        UI.LabeledField { onAccepted: root.accepted(); id:before; width:parent.width; label:Translations.text("webapps.fields.before") }
        UI.LabeledField { onAccepted: root.accepted(); id:after; width:parent.width; label:Translations.text("webapps.fields.after") }
    }
    UI.ColumnText { width:parent.width; text:root.parseError; visible:!!text; color:Theme.urgent; wrapMode:Text.Wrap }
}
