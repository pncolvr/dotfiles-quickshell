pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../services"
import "../../theme"
import "../../theme/ui" as UI

ManagedCollectionPanel {
    managementTypes: [{name:'remote',description:Translations.text("remotes.type.sshTunnel")},{name:'vm',description:Translations.text("remotes.type.virtualMachine")}]
    id: root
    service: RemoteService
    collectionName: Translations.text("remotes.title")
    pickerMode: PickerService.Mode.Remotes
    entryForm: RemoteForm {}
    canRemoveEntry: entry => !RemoteService.sessions.some(session=>session.id===entry.id)
    Shortcut {
        sequence: 'Ctrl+R'
        enabled: root.sessionActive && !root.managing
        onActivated: RemoteService.toggleActiveOnly()
    }
    listActionButtons: Component {
        Row {
            spacing:Theme.controlSpacing
            UI.ActionButton {
                objectName:'remoteRunningOnly'; label:Translations.text("remotes.filter.running")
                checkable:true; checked:RemoteService.activeOnly
                foreground:checked ? Theme.accent : Theme.inactive
                hint:Translations.text("remotes.filter.runningHint")
                onClicked:RemoteService.toggleActiveOnly()
            }
            UI.ActionButton {
                objectName:'remoteDisconnect'; label:Translations.text("remotes.actions.disconnect")
                enabled:!!RemoteService.selectedSession && RemoteService.selectedSession.state!=='disconnecting'
                hint:Translations.text("remotes.actions.disconnectHint"); onClicked:RemoteService.disconnectSelected()
            }
            UI.ActionButton {
                objectName:'remoteShutdown'; label:Translations.text("remotes.actions.shutdown")
                visible:RemoteService.selectedEntry?.type==='vm'
                enabled:!RemoteService.busy; fillColor:Theme.urgent
                hint:Translations.text("remotes.actions.shutdownHint"); onClicked:RemoteService.shutdownSelected()
            }
        }
    }
}
