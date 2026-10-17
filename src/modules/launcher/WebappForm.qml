pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui" as UI
import "../../services/launcher/CommandArguments.mjs" as Arguments

Column {
    id: root
    property bool readOnly: false
    property var original: ({})
    property alias browser: browserFields.browser
    property alias browserProfile: browserFields.browserProfile
    property alias windowMode: browserFields.windowMode
    property string entryCategory: 'personal'
    property bool entryEnabled: true
    property string parseError: ''
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { name.focusInput() }
    function load(entry) {
        original=entry; name.text=entry.name; url.text=entry.url; browser=entry.browser; browserProfile=entry.profile
        windowMode=entry.windowMode; entryEnabled=entry.enabled; entryCategory=entry.category || 'personal'
        extra.text=Arguments.join(entry.arguments); before.text=Arguments.join(entry.before); after.text=Arguments.join(entry.after)
        parseError=''
    }
    function value() {
        parseError=''
        try {
            return Object.assign({},original,{name:name.text,url:url.text,browser,profile:browserProfile,windowMode,
                enabled:entryEnabled,category:entryCategory,arguments:Arguments.split(extra.text),
                before:Arguments.command(before.text),after:Arguments.command(after.text)})
        } catch (error) { parseError=Translations.message(error); return null }
    }
    UI.LabeledField { readOnly: root.readOnly; onAccepted: root.accepted(); id: name; inputObjectName:'webappName'; width: parent.width; label:Translations.text("common.fields.name") }
    UI.LabeledField { readOnly: root.readOnly; onAccepted: root.accepted(); id: url; inputObjectName:'webappUrl'; width: parent.width; label:Translations.text("common.fields.url"); placeholderText:'https://example.com' }
    BrowserLaunchFields { readOnly: root.readOnly; id:browserFields; width:parent.width }
    EntryCategorySelector { readOnly: root.readOnly;
        objectName:'webappCategorySelector'
        toggleObjectName:'webappCategoryToggle'
        choicesObjectName:'webappCategoryChoices'
        width: parent.width
        selectedName:root.entryCategory
        onSelected: name => root.entryCategory=name
    }
    UI.CheckBox {
        objectName: "webappEnabled"
        text: Translations.text("common.states.enabled")
        checked: root.entryEnabled
        enabled: !root.readOnly
        onToggled: root.entryEnabled = checked
    }
    Column {
        width: parent.width; spacing:Theme.controlSpacing
        UI.LabeledField { readOnly: root.readOnly; onAccepted: root.accepted(); id:extra; width:parent.width; label:Translations.text("webapps.fields.arguments") }
        UI.LabeledField { readOnly: root.readOnly; onAccepted: root.accepted(); id:before; width:parent.width; label:Translations.text("webapps.fields.before") }
        UI.LabeledField { readOnly: root.readOnly; onAccepted: root.accepted(); id:after; width:parent.width; label:Translations.text("webapps.fields.after") }
    }
    UI.ColumnText { width:parent.width; text:root.parseError; visible:!!text; color:Theme.urgent; wrapMode:Text.Wrap }
}
