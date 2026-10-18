pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../ui" as UI
import "../../theme"
import "../../i18n"
import "../../services/launcher/CommandArguments.mjs" as Arguments
import "../../services/browser/desktop/DesktopApplications.mjs" as Applications
import "../../services/browser/BrowserRouting.mjs" as Routing

Column {
    id: root
    objectName: 'browserRoutingForm'
    property bool readOnly: false
    property var original: ({})
    property string parseError: ''
    property string desktopId: ''
    property string applicationName: ''
    property string customCommand: ''
    property var applicationCommand: []
    readonly property var applications: Applications.applications(DesktopEntries.applications.values)
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { name.focusInput() }
    function updateApplicationCommand() {
        if (desktopId) command.text=Arguments.join(applicationCommand.map(word=>word.replace(/\{url\}/g,()=>targetTemplate.text)))
    }
    function load(entry) {
        original=entry; name.text=entry.name; pattern.text=entry.pattern
        contains.text=Routing.containsPatterns(entry).join('\n')
        matching.selectedName=entry.match; workspace.text=String(entry.workspace)
        browser.browser=entry.browser; browser.browserProfile=entry.profile; browser.windowMode=entry.windowMode
        enabledBox.checked=entry.enabled
        operation.selectedName=entry.action || 'browser'
        parameter.text=entry.parameter ?? 'url'
        command.text=Arguments.join(entry.command ?? [])
        desktopId=entry.desktopId ?? ''; applicationName=entry.applicationName ?? ''
        applicationCommand=entry.command ?? []
        targetTemplate.text=entry.targetTemplate ?? '{url}'
        customCommand=desktopId ? '' : command.text
        application.selectedName=desktopId
        extraArguments.text=Arguments.join(entry.extraArguments ?? [])
        process.checked=!!entry.onlyWhenRunning
        parseError=''
        updateApplicationCommand()
    }
    function value() {
        parseError=''
        try {
            const argv=operation.selectedName==='command' ? (desktopId ? applicationCommand : Arguments.command(command.text)) : []
            const processName=argv[0]===original.command?.[0] && original.onlyWhenRunning
                ? original.onlyWhenRunning : (argv[0] ?? '').split('/').pop()
            const patterns=matching.selectedName==='contains' ? contains.values() : undefined
            return Object.assign({},original,{name:name.text,pattern:patterns ? (patterns[0] ?? '') : pattern.text,patterns,match:matching.selectedName,
            workspace:Number(workspace.text),browser:browser.browser,
            profile:browser.browserProfile,windowMode:browser.windowMode,enabled:enabledBox.checked,
            action:operation.selectedName,parameter:parameter.text,command:argv,
            desktopId,applicationName,targetTemplate:targetTemplate.text,extraArguments:Arguments.split(extraArguments.text),onlyWhenRunning:process.checked ? processName : ''}) }
        catch(exception) { parseError=Translations.message(exception); return null }
    }
    UI.LabeledField { id:name; width:parent.width; readOnly:root.readOnly; label:Translations.text('common.fields.name'); onAccepted:root.accepted() }
    UI.ComboSelector {
        id:matching; width:parent.width; readOnly:root.readOnly; compact:true
        label:Translations.text('browser.routing.match',[selectedDescription])
        options:['contains','host','glob','regex'].map(value=>({name:value,description:Translations.text('browser.routing.match.'+value)}))
        onSelected:name=>matching.selectedName=name
    }
    UI.LabeledField { id:pattern; inputObjectName:'browserRoutePattern'; width:parent.width; readOnly:root.readOnly; visible:matching.selectedName!=='contains'; label:Translations.text('browser.routing.pattern'); onAccepted:root.accepted() }
    UI.LineListField {
        id:contains
        inputObjectName:'browserRouteContains'
        width:parent.width
        readOnly:root.readOnly
        visible:matching.selectedName==='contains'
        label:Translations.text('browser.routing.containsList')
        hint:Translations.text('browser.routing.containsListHint')
    }
    UI.ComboSelector {
        id:operation; width:parent.width; readOnly:root.readOnly; compact:true
        objectName:'browserRouteAction'
        label:Translations.text('browser.routing.action',[selectedDescription])
        options:['browser','redirect','query','command'].map(value=>({name:value,description:Translations.text('browser.routing.action.'+value)}))
        onSelected:name=>operation.selectedName=name
    }
    BrowserLaunchFields { id:browser; width:parent.width; readOnly:root.readOnly; visible:operation.selectedName==='browser' }
    UI.LabeledField { id:parameter; inputObjectName:'browserRouteParameter'; width:parent.width; readOnly:root.readOnly; visible:operation.selectedName==='query'; label:Translations.text('browser.routing.parameter'); onAccepted:root.accepted() }
    UI.ComboSelector {
        id:application; objectName:'browserRouteApplication'; width:parent.width; readOnly:root.readOnly; compact:true; searchable:true
        visible:operation.selectedName==='command'
        label:Translations.text('browser.routing.application',[selectedDescription])
        options:[{name:'',description:Translations.text('browser.routing.customCommand')}].concat(root.applications.map(entry=>({name:entry.id,description:entry.name})))
        onSelected: id=>{
            if (!root.desktopId) root.customCommand=command.text
            selectedName=id; root.desktopId=id
            const entry=root.applications.find(value=>value.id===id)
            root.applicationName=entry?.name ?? ''
            root.applicationCommand=entry?.command ?? []
            if (entry) root.updateApplicationCommand()
            else command.text=root.customCommand
        }
    }
    UI.LabeledField {
        id:command
        inputObjectName:'browserRouteCommand'
        width:parent.width
        readOnly:root.readOnly || !!root.desktopId
        visible:operation.selectedName==='command'
        label:Translations.text(root.desktopId ? 'browser.routing.applicationCommand' : 'browser.routing.command')
        hint:Translations.text(root.desktopId ? 'browser.routing.applicationCommandHint' : 'browser.routing.commandHint')
        onAccepted:root.accepted()
    }
    UI.LabeledField {
        id:targetTemplate
        inputObjectName:'browserRouteTargetTemplate'
        width:parent.width
        readOnly:root.readOnly
        visible:operation.selectedName==='command' && !!root.desktopId
        text:'{url}'
        label:Translations.text('browser.routing.targetTemplate')
        hint:Translations.text('browser.routing.targetTemplateHint')
        onTextChanged:root.updateApplicationCommand()
        onAccepted:root.accepted()
    }
    UI.LabeledField { id:extraArguments; inputObjectName:'browserRouteExtraArguments'; width:parent.width; readOnly:root.readOnly; visible:operation.selectedName==='command'; label:Translations.text('browser.routing.extraArguments'); hint:Translations.text('browser.routing.extraArgumentsHint'); onAccepted:root.accepted() }
    UI.CheckBox { id:process; objectName:'browserRouteOnlyWhenRunning'; enabled:!root.readOnly; visible:operation.selectedName==='command'; text:Translations.text('browser.routing.process') }
    UI.LabeledField { id:workspace; visible:['browser','command'].includes(operation.selectedName); width:parent.width; readOnly:root.readOnly; label:Translations.text('browser.routing.workspace'); onAccepted:root.accepted() }
    UI.CheckBox { id:enabledBox; enabled:!root.readOnly; text:Translations.text('common.states.enabled') }
    UI.ColumnText { width:parent.width; text:root.parseError; visible:!!text; color:Theme.urgent; wrapMode:Text.Wrap }
}
