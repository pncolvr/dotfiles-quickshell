pragma ComponentBehavior: Bound
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
        } catch (error) { parseError=error.message; return null }
    }
    UI.LabeledField { onAccepted: root.accepted(); id: name; inputObjectName:'webappName'; width: parent.width; label:'Name' }
    UI.LabeledField { onAccepted: root.accepted(); id: url; inputObjectName:'webappUrl'; width: parent.width; label:'URL'; placeholderText:'https://example.com' }
    BrowserLaunchFields { id:browserFields; width:parent.width }
    UI.ComboSelector {
        objectName:'webappCategorySelector'
        toggleObjectName:'webappCategoryToggle'
        choicesObjectName:'webappCategoryChoices'
        width: parent.width; compact:true; labelPrefix:'Category: '
        options:[{name:'personal',description:'Personal'},{name:'work',description:'Work'}]
        selectedName:root.entryCategory
        onSelected: name => root.entryCategory=name
    }
    UI.ActionButton {
        objectName:'webappEnabled'
        label: root.entryEnabled ? 'Enabled' : 'Disabled'
        checkable:true; checked:root.entryEnabled
        foreground: root.entryEnabled ? Theme.accent : Theme.inactive
        hint: 'Include this webapp in the picker'
        onClicked: root.entryEnabled=!root.entryEnabled
    }
    UI.ActionButton {
        objectName:'webappAdvanced'
        label:'Advanced'; glyph:Theme.chevronDownIcon
        checkable:true; checked:root.advanced
        foreground: root.advanced ? Theme.accent : Theme.text
        hint: 'Additional launch options'
        onClicked: root.advanced=!root.advanced
    }
    Column {
        width: parent.width; spacing:Theme.controlSpacing; visible:root.advanced
        UI.LabeledField { onAccepted: root.accepted(); id:extra; width:parent.width; label:'Browser arguments (literal, quoted arguments supported)' }
        UI.LabeledField { onAccepted: root.accepted(); id:before; width:parent.width; label:'Before opening: executable and arguments (optional)' }
        UI.LabeledField { onAccepted: root.accepted(); id:after; width:parent.width; label:'After opening: executable and arguments (optional)' }
    }
    UI.ColumnText { width:parent.width; text:root.parseError; visible:!!text; color:Theme.urgent; wrapMode:Text.Wrap }
}
