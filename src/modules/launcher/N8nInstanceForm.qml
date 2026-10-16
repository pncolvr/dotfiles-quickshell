pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../theme/ui" as UI

Column {
    id: root
    property var original: ({})
    property string category: 'personal'
    property bool entryEnabled: true
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { name.focusInput() }
    function load(entry) {
        original=entry; name.text=entry.name; url.text=entry.url; key.text=entry.apiKey; key.revealed=false
        browser.browser=entry.browser; browser.browserProfile=entry.profile; browser.windowMode=entry.windowMode
        category=entry.category; entryEnabled=entry.enabled
    }
    function value() {
        return Object.assign({},original,{name:name.text,url:url.text,apiKey:key.text,browser:browser.browser,
            profile:browser.browserProfile,windowMode:browser.windowMode,category,enabled:entryEnabled})
    }
    UI.LabeledField { id:name; width:parent.width; label:'Name'; inputObjectName:'n8nName'; onAccepted:root.accepted() }
    UI.LabeledField { id:url; width:parent.width; label:'Instance address'; inputObjectName:'n8nUrl'; placeholderText:'https://n8n.example.com'; onAccepted:root.accepted() }
    UI.ColumnText { text:'API key'; color:Theme.inactive }
    UI.SecretField { id:key; width:parent.width; objectName:'n8nApiKey'; onAccepted:root.accepted() }
    BrowserLaunchFields { id:browser; width:parent.width; objectNamePrefix:'n8n' }
    UI.ComboSelector {
        objectName:'n8nCategorySelector'; width:parent.width; compact:true; labelPrefix:'Category: '
        options:[{name:'personal',description:'Personal'},{name:'work',description:'Work'}]
        selectedName:root.category; onSelected: name => root.category=name
    }
    UI.ActionButton {
        label:root.entryEnabled ? 'Enabled' : 'Disabled'; checkable:true; checked:root.entryEnabled
        foreground:root.entryEnabled ? Theme.accent : Theme.inactive
        hint:'Include this instance in the picker'; onClicked:root.entryEnabled=!root.entryEnabled
    }
}
