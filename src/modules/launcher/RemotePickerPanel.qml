pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../services"
import "../../theme"
import "../../theme/ui" as UI

ManagedCollectionPanel {
    managementTypes: [{name:'ssh',description:Translations.text("remotes.type.sshTerminal")},{name:'remote',description:Translations.text("remotes.type.sshTunnel")},{name:'vm',description:Translations.text("remotes.type.virtualMachine")}]
    id: root
    service: RemoteService
    collectionName: Translations.text("remotes.title")
    pickerMode: PickerService.Mode.Remotes
    entryForm: RemoteForm {}
    canRemoveEntry: entry => !RemoteService.sessions.some(session=>session.id===entry.id)
    listActionButtons: Component {
        Item {
            implicitHeight: buttons.implicitHeight
            Row {
                id: buttons
                anchors.right: parent.right
                spacing:Theme.controlSpacing
                UI.ActionButton {
                    objectName:'remoteRunningOnly'
                    glyph: Theme.filterIcon
                    keyAction: "remotes.runningOnly"
                    checkable:true; checked:RemoteService.activeOnly
                    enabled: RemoteService.hasActiveSessions
                    foreground:checked ? Theme.accent : Theme.inactive
                    hint:Translations.text("remotes.filter.runningHint")
                    onClicked:RemoteService.toggleActiveOnly()
                }
                UI.ActionButton {
                    objectName:'remoteDisconnect'
                    glyph: Theme.disconnectIcon
                    enabled:!!RemoteService.selectedSession && RemoteService.selectedSession.state!=='disconnecting'
                    hint:Translations.text("remotes.actions.disconnectHint"); onClicked:RemoteService.disconnectSelected()
                }
                UI.ActionButton {
                    objectName:'remoteShutdown'
                    glyph: Theme.powerShutdownIcon
                    visible:RemoteService.selectedEntry?.type==='vm'
                    enabled:RemoteService.canShutdownSelected; fillColor:Theme.urgent
                    hint:Translations.text("remotes.actions.shutdownHint"); onClicked:RemoteService.shutdownSelected()
                }
            }
        }
    }
}
