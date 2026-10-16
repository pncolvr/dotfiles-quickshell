pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../theme/ui" as UI
import "../../services/launcher/CommandArguments.mjs" as Arguments

Column {
    id: root
    property var original: ({})
    property string connectionType: 'remote'
    property string entryCategory: 'personal'
    property bool entryEnabled: true
    property bool advanced: false
    property string parseError: ''
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { name.focusInput() }
    function load(entry) {
        original=entry; name.text=entry.name; connectionType=entry.type; entryCategory=entry.category
        entryEnabled=entry.enabled; endpoint.text=entry.endpoint; port.text=String(entry.port)
        username.text=entry.username; password.text=entry.password; password.revealed=false
        domain.text=entry.domain; title.text=entry.displayName; hop.text=entry.hopHost
        hopUser.text=entry.hopUsername; sshKey.text=entry.sshKeyPath; vm.text=entry.vmName
        extra.text=Arguments.join(entry.arguments); advanced=false; parseError=''
    }
    function value() {
        parseError=''
        try {
            return Object.assign({},original,{name:name.text,type:connectionType,category:entryCategory,enabled:entryEnabled,
                endpoint:endpoint.text,port:Number(port.text),username:username.text,password:password.text,domain:domain.text,
                displayName:title.text,hopHost:hop.text,hopUsername:hopUser.text,sshKeyPath:sshKey.text,
                vmName:vm.text,arguments:Arguments.split(extra.text)})
        } catch (error) { parseError=error.message; return null }
    }
    UI.LabeledField { id:name; inputObjectName:'remoteName'; width:parent.width; label:'Name'; onAccepted:root.accepted() }
    UI.ComboSelector {
        objectName:'remoteTypeSelector'; width:parent.width; compact:true; labelPrefix:'Connection: '
        options:[{name:'remote',description:'RDP through SSH tunnel'},{name:'vm',description:'Virtual machine'}]
        selectedName:root.connectionType; onSelected:name=>root.connectionType=name
    }
    UI.ComboSelector {
        objectName:'remoteCategorySelector'; width:parent.width; compact:true; labelPrefix:'Category: '
        options:[{name:'personal',description:'Personal'},{name:'work',description:'Work'}]
        selectedName:root.entryCategory; onSelected:name=>root.entryCategory=name
    }
    UI.LabeledField { id:endpoint; inputObjectName:'remoteEndpoint'; width:parent.width; label:'RDP host'; onAccepted:root.accepted() }
    UI.LabeledField { id:port; inputObjectName:'remotePort'; width:parent.width; label:'RDP port'; onAccepted:root.accepted() }
    UI.LabeledField { id:username; inputObjectName:'remoteUsername'; width:parent.width; label:'Username'; onAccepted:root.accepted() }
    UI.ColumnText { text:'Password'; color:Theme.inactive }
    UI.SecretField { id:password; objectName:'remotePassword'; width:parent.width; onAccepted:root.accepted() }
    Column {
        width:parent.width; spacing:Theme.controlSpacing; visible:root.connectionType==='remote'
        UI.LabeledField { id:hop; inputObjectName:'remoteHop'; width:parent.width; label:'SSH jump host'; onAccepted:root.accepted() }
        UI.LabeledField { id:hopUser; inputObjectName:'remoteHopUsername'; width:parent.width; label:'SSH username'; onAccepted:root.accepted() }
        UI.LabeledField { id:sshKey; inputObjectName:'remoteKey'; width:parent.width; label:'SSH key path (optional)'; onAccepted:root.accepted() }
    }
    UI.LabeledField { id:vm; inputObjectName:'remoteVm'; width:parent.width; visible:root.connectionType==='vm'; label:'Virtual machine'; onAccepted:root.accepted() }
    UI.ActionButton {
        objectName:'remoteEnabled'; label:root.entryEnabled ? 'Enabled' : 'Disabled'; checkable:true; checked:root.entryEnabled
        foreground:root.entryEnabled ? Theme.accent : Theme.inactive
        hint:'Include this connection in the picker'; onClicked:root.entryEnabled=!root.entryEnabled
    }
    UI.ActionButton {
        label:'Advanced'; glyph:Theme.chevronDownIcon; checkable:true; checked:root.advanced
        hint:'Additional connection options'; onClicked:root.advanced=!root.advanced
    }
    Column {
        width:parent.width; spacing:Theme.controlSpacing; visible:root.advanced
        UI.LabeledField { id:domain; width:parent.width; label:'Domain (optional)'; onAccepted:root.accepted() }
        UI.LabeledField { id:title; width:parent.width; label:'Window title (optional)'; onAccepted:root.accepted() }
        UI.LabeledField { id:extra; width:parent.width; label:'RDP arguments (literal, quoted arguments supported)'; onAccepted:root.accepted() }
    }
    UI.ColumnText { width:parent.width; text:root.parseError; visible:!!text; color:Theme.urgent; wrapMode:Text.Wrap }
}
