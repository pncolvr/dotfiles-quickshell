pragma ComponentBehavior: Bound
import QtQuick
import "../../services"
import "../../theme"
import "../../theme/ui" as UI

ManagedCollectionPanel {
    id: root
    service: RemoteService
    collectionName: 'Remotes'
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
                objectName:'remoteRunningOnly'; label:'Running only'
                checkable:true; checked:RemoteService.activeOnly
                foreground:checked ? Theme.accent : Theme.inactive
                hint:'Show running and connecting sessions (Ctrl+R)'
                onClicked:RemoteService.toggleActiveOnly()
            }
            UI.ActionButton {
                objectName:'remoteDisconnect'; label:'Disconnect'
                enabled:!!RemoteService.selectedSession && RemoteService.selectedSession.state!=='disconnecting'
                hint:'Disconnect only this managed connection'; onClicked:RemoteService.disconnectSelected()
            }
            UI.ActionButton {
                objectName:'remoteShutdown'; label:'Shut down VM'
                visible:RemoteService.selectedEntry?.type==='vm'
                enabled:!RemoteService.busy; fillColor:Theme.urgent
                hint:'Shut down the selected virtual machine'; onClicked:RemoteService.shutdownSelected()
            }
        }
    }
}
