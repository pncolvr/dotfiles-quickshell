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
    property string connectionType: 'remote'
    readonly property bool sshConnection: connectionType === 'ssh'
    property string entryCategory: 'personal'
    property bool entryEnabled: true
    property string parseError: ''
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { name.focusInput() }
    function load(entry) {
        jumpToggle.expanded=false
        original=entry; name.text=entry.name; connectionType=entry.type; entryCategory=entry.category
        entryEnabled=entry.enabled; endpoint.text=entry.endpoint; port.text=String(entry.port)
        username.text=entry.username; password.text=entry.password; password.revealed=false
        domain.text=entry.domain; title.text=entry.displayName; hop.text=entry.hopHost
        hopUser.text=entry.hopUsername; sshKey.text=entry.sshKeyPath; vm.text=entry.vmName
        hopPort.text=String(entry.hopPort ?? 22); hopPassword.text=entry.hopPassword ?? ''; hopPassword.revealed=false
        hopKey.text=entry.hopKeyPath ?? ''; targetKey.text=entry.sshKeyPath
        sshExtra.text=Arguments.join(entry.sshArguments ?? [])
        extra.text=Arguments.join(entry.arguments); parseError=''
    }
    function value() {
        parseError=''
        try {
            return Object.assign({},original,{name:name.text,type:connectionType,category:entryCategory,enabled:entryEnabled,
                endpoint:endpoint.text,port:Number(port.text),username:username.text,password:password.text,domain:domain.text,
                displayName:title.text,hopHost:hop.text,hopUsername:hopUser.text,sshKeyPath:sshConnection ? targetKey.text : sshKey.text,
                hopPort:Number(hopPort.text),hopPassword:hopPassword.text,hopKeyPath:hopKey.text,sshArguments:Arguments.split(sshExtra.text),
                vmName:vm.text,arguments:Arguments.split(extra.text)})
        } catch (error) { parseError=Translations.message(error); return null }
    }
    UI.LabeledField { readOnly: root.readOnly; id:name; inputObjectName:'remoteName'; width:parent.width; label:Translations.text("common.fields.name"); onAccepted:root.accepted() }
    UI.ComboSelector { readOnly: root.readOnly;
        objectName:'remoteTypeSelector'; width:parent.width; compact:true; label: Translations.text("remotes.type.label", [selectedDescription])
        options:[{name:'ssh',description:Translations.text("remotes.type.sshTerminal")},{name:'remote',description:Translations.text("remotes.type.sshTunnel")},{name:'vm',description:Translations.text("remotes.type.virtualMachine")}]
        selectedName:root.connectionType
        onSelected: name => {
            if ((name === 'ssh') !== root.sshConnection && ['22','3389'].includes(port.text))
                port.text = name === 'ssh' ? '22' : '3389'
            root.connectionType = name
        }
    }
    EntryCategorySelector { readOnly: root.readOnly;
        objectName:'remoteCategorySelector'; width:parent.width
        selectedName:root.entryCategory; onSelected:name=>root.entryCategory=name
    }
    Row {
        width: parent.width
        spacing: Theme.controlSpacing
    UI.LabeledField { readOnly: root.readOnly; id:endpoint; inputObjectName:'remoteEndpoint'; width: (parent.width - parent.spacing) * 0.7; label:Translations.text(root.sshConnection ? "remotes.fields.sshHost" : "remotes.fields.host"); onAccepted:root.accepted() }
    UI.LabeledField { readOnly: root.readOnly; id:port; inputObjectName:'remotePort'; width: (parent.width - parent.spacing) * 0.3; label:Translations.text(root.sshConnection ? "remotes.fields.sshPort" : "remotes.fields.port"); onAccepted:root.accepted() }
    }
    UI.LabeledField { readOnly: root.readOnly; id:username; inputObjectName:'remoteUsername'; width:parent.width; label:Translations.text(root.sshConnection ? "remotes.fields.optionalUsername" : "common.fields.username"); onAccepted:root.accepted() }
    UI.ColumnText { text:Translations.text("common.fields.password"); color:Theme.inactive }
    UI.SecretField { readOnly: root.readOnly; id:password; objectName:'remotePassword'; width:parent.width; onAccepted:root.accepted() }
    UI.LabeledField { readOnly: root.readOnly; id:targetKey; inputObjectName:'remoteTargetKey'; width:parent.width; visible:root.sshConnection; label:Translations.text("remotes.fields.sshKey"); onAccepted:root.accepted() }
    Column {
        width:parent.width; spacing:Theme.controlSpacing; visible:root.connectionType==='remote' || root.sshConnection
        UI.CollapsibleSection {
            id: jumpToggle
            objectName: 'remoteJumpToggle'
            width: parent.width
            text: Translations.text("remotes.fields.jumpHost")
            onExpansionRequested: expanded => jumpToggle.expanded = expanded
            onExpandedChanged: if (!expanded) hopPassword.revealed=false
            contentItem: UI.ColumnText {
                centerVertical: false
                text: jumpToggle.text
                color: Theme.inactive
            }
        }
        Column {
            width:parent.width - x; x:Theme.controlFieldPadding; spacing:Theme.controlSpacing
            visible:jumpToggle.showingContent
            UI.LabeledField { readOnly: root.readOnly; id:hop; inputObjectName:'remoteHop'; width:parent.width; label:Translations.text(root.sshConnection ? "remotes.fields.optionalJumpHost" : "remotes.fields.jumpHost"); onAccepted:root.accepted() }
            UI.LabeledField { readOnly: root.readOnly; id:hopPort; inputObjectName:'remoteHopPort'; width:parent.width; visible:root.sshConnection; label:Translations.text("remotes.fields.jumpPort"); onAccepted:root.accepted() }
            UI.LabeledField { readOnly: root.readOnly; id:hopUser; inputObjectName:'remoteHopUsername'; width:parent.width; label:Translations.text(root.sshConnection ? "remotes.fields.jumpUsername" : "remotes.fields.sshUsername"); onAccepted:root.accepted() }
            UI.ColumnText { visible:root.sshConnection; text:Translations.text("remotes.fields.jumpPassword"); color:Theme.inactive }
            UI.SecretField { readOnly:root.readOnly; id:hopPassword; objectName:'remoteHopPassword'; width:parent.width; visible:root.sshConnection; onAccepted:root.accepted() }
            UI.LabeledField { readOnly:root.readOnly; id:hopKey; inputObjectName:'remoteHopKey'; width:parent.width; visible:root.sshConnection; label:Translations.text("remotes.fields.jumpKey"); onAccepted:root.accepted() }
            UI.LabeledField { readOnly: root.readOnly; id:sshKey; inputObjectName:'remoteKey'; width:parent.width; visible:!root.sshConnection; label:Translations.text("remotes.fields.sshKey"); onAccepted:root.accepted() }
        }
    }
    UI.LabeledField { readOnly: root.readOnly; id:vm; inputObjectName:'remoteVm'; width:parent.width; visible:root.connectionType==='vm'; label:Translations.text("remotes.type.virtualMachine"); onAccepted:root.accepted() }
    UI.CheckBox {
        objectName: "remoteEnabled"
        text: Translations.text("common.states.enabled")
        checked: root.entryEnabled
        enabled: !root.readOnly
        onToggled: root.entryEnabled = checked
    }
    Column {
        width:parent.width; spacing:Theme.controlSpacing
        UI.LabeledField { readOnly: root.readOnly; id:domain; width:parent.width; visible:!root.sshConnection; label:Translations.text("remotes.fields.domain"); onAccepted:root.accepted() }
        UI.LabeledField { readOnly: root.readOnly; id:title; width:parent.width; visible:!root.sshConnection; label:Translations.text("remotes.fields.windowTitle"); onAccepted:root.accepted() }
        UI.LabeledField { readOnly: root.readOnly; id:extra; width:parent.width; visible:!root.sshConnection; label:Translations.text("remotes.fields.arguments"); onAccepted:root.accepted() }
        UI.LabeledField { readOnly: root.readOnly; id:sshExtra; inputObjectName:'remoteSshArguments'; width:parent.width; visible:root.sshConnection; label:Translations.text("remotes.fields.sshArguments"); onAccepted:root.accepted() }
    }
}
