pragma Singleton
import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../launcher"
import "../../config"
import "RemoteEntries.mjs" as Entries

ManagedCollectionService {
    id: root
    repository: RemoteRepository
    pickerMode: PickerService.Mode.Remotes
    collectionName: Translations.text("remotes.title")
    acceptLabel: Translations.text(selectedSession ? "remotes.actions.disconnect" : "remotes.actions.connect")
    busy: shutdownTask.running
    property var sessions: []
    property var pendingControls: []
    property var disconnectingIds: []
    readonly property string workerPath: Quickshell.shellPath('src/services/remotes/remote-worker.sh')
    readonly property string runtimeDatabase: Config.databasePath.slice(0,Config.databasePath.lastIndexOf('/'))+'/remotes-runtime.db'
    readonly property var selectedEntry: entries.find(entry=>entry.id===PickerService.currentItem?.result) ?? null
    readonly property var selectedSession: sessions.find(session=>session.id===selectedEntry?.id) ?? null
    readonly property bool hasActiveSessions: activeFilterIds.length > 0
    readonly property string selectedVmName: PickerService.visible && PickerService.mode === pickerMode
        && !managing && selectedEntry?.type === 'vm' ? selectedEntry.vmName : ''
    property string runningVmName: ''
    readonly property bool canShutdownSelected: !!selectedVmName && runningVmName === selectedVmName && !busy
    onSelectedVmNameChanged: { runningVmName = ''; refreshVmState() }
    onHasActiveSessionsChanged: if (!hasActiveSessions) activeOnly = false
    activeEntryIds: sessions.map(session=>session.id)
    activeFilterIds: sessions.filter(session=>session.state!=='disconnecting').map(session=>session.id)
    itemForEntry: entry => {
        const session=root.sessions.find(session=>session.id===entry.id)
        const subtitle=session ? root.stateLabel(session.state,entry.type)+' · '+entry.endpoint : entry.endpoint
        return {id:entry.id,title:entry.name,subtitle,search:entry.name+' '+entry.endpoint,result:entry.id}
    }
    function stateLabel(state, type = '') {
        switch (state) {
            case 'connecting': return Translations.text("remotes.states.connecting")
            case 'running': return Translations.text(type === 'ssh' ? "remotes.states.sshRunning" : "remotes.states.running")
            case 'disconnecting': return Translations.text("remotes.states.disconnecting")
            default: return ''
        }
    }
    function newEntry() { edit(Entries.empty(Config.remoteRdpArguments)) }
    function toggleActiveOnly() {
        if (!hasActiveSessions) return
        activeOnly = !activeOnly
        PickerService.opened()
    }
    function refreshVmState() {
        if (!selectedVmName || vmProbe.running || busy) return
        vmProbe.vmName = selectedVmName
        vmProbe.command = ['timeout','3'].concat(Config.remoteVmCommand,['domid','--',selectedVmName])
        vmProbe.running = true
    }
    function workerOptions() {
        return JSON.stringify({rdp:Config.remoteRdpCommand,ssh:Config.remoteSshCommand,virsh:Config.remoteVmCommand,
            probe:Config.remoteProbeCommand,waitSeconds:Config.remoteVmWaitSeconds,
            terminal:Config.remoteTerminalCommand})
    }
    function accept(items) {
        if (managing || busy || !items.length) return
        const entry=entries.find(entry=>entry.id===items[0].result)
        if (!entry) return
        if (sessions.some(session=>session.id===entry.id)) { disconnect(entry.id); return }
        if (!entry.enabled) return
        try { Entries.validate(entry) } catch (exception) { error=Translations.message(exception); return }
        Quickshell.execDetached({command:['bash',workerPath,'--run',runtimeDatabase,entry.id,
            Config.databasePath,Quickshell.shellDir,workerOptions()],unbindStdout:true})
        sessions=sessions.concat([{id:entry.id,state:'connecting'}])
        PickerService.close()
    }
    function request(action='--status',id='') {
        if (!DbService.ready) return
        if (controller.running) {
            if (action!=='--status' && !pendingControls.some(request=>request.action===action && request.id===id))
                pendingControls=pendingControls.concat([{action,id}])
            return
        }
        controller.action=action
        controller.entryId=id
        controller.command=['bash',workerPath,action,runtimeDatabase,id]
        controller.running=true
    }
    function disconnect(id) {
        const session=sessions.find(session=>session.id===id)
        if (!session || session.state==='disconnecting') return
        error=''
        disconnectingIds=disconnectingIds.concat([id])
        sessions=sessions.map(session=>session.id===id ? Object.assign({},session,{state:'disconnecting'}) : session)
        request('--disconnect',id)
    }
    function disconnectSelected() { disconnect(selectedEntry?.id) }
    function shutdownSelected() {
        if (!canShutdownSelected) return
        shutdownTask.command=Config.remoteVmCommand.concat(['shutdown','--',selectedEntry.vmName])
        shutdownTask.running=true
    }
    onSessionsChanged: syncPicker()
    Timer { interval: root.sessions.length ? 1000 : 5000; running: DbService.ready; repeat:true; onTriggered: root.request() }
    Timer { interval: 1000; running: !!root.selectedVmName; repeat:true; onTriggered: root.refreshVmState() }
    Connections { target: DbService; function onReadyChanged() { root.request() } }
    Component.onCompleted: request()
    Process {
        id: controller
        property string action: '--status'
        property string entryId: ''
        stdout: StdioCollector {
            onStreamFinished: {
                if (controller.action!=='--status') return
                try {
                    const value=JSON.parse(text)
                    if (!Array.isArray(value)) return
                    root.disconnectingIds=root.disconnectingIds.filter(id=>value.some(session=>session.id===id) ||
                        root.pendingControls.some(request=>request.id===id && request.action==='--disconnect'))
                    root.sessions=value.map(session=>root.disconnectingIds.includes(session.id)
                        ? Object.assign({},session,{state:'disconnecting'}) : session)
                } catch (_) { /* Keep the previous state on an incomplete reply. */ }
            }
        }
        stderr: StdioCollector { waitForEnd:true }
        // qmllint disable signal-handler-parameters
        onExited: (code,status) => {
            if (code || status) {
                root.error=Translations.text("remotes.errors.control")
                if (action==='--disconnect') root.disconnectingIds=root.disconnectingIds.filter(id=>id!==controller.entryId)
            }
            const pending=root.pendingControls[0]
            root.pendingControls=root.pendingControls.slice(1)
            if (pending) Qt.callLater(()=>root.request(pending.action,pending.id))
            else if (action!=='--status') Qt.callLater(()=>root.request())
        }
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: vmProbe
        property string vmName: ''
        stdout: StdioCollector { id: vmId; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (code,status) => {
            if (vmName !== root.selectedVmName) { Qt.callLater(root.refreshVmState); return }
            root.runningVmName = !code && !status && /^[0-9]+$/.test(vmId.text.trim()) ? vmName : ''
        }
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: shutdownTask
        stdout: StdioCollector { waitForEnd:true }
        stderr: StdioCollector { waitForEnd:true }
        // qmllint disable signal-handler-parameters
        onExited: (code,status) => {
            if (code || status) root.error=Translations.text("remotes.errors.shutdown")
            else {
                root.runningVmName = ''
                AlertService.post('remotes',Translations.text("remotes.status.shutdownRequested"),'info',3000)
            }
            Qt.callLater(root.refreshVmState)
        }
        // qmllint enable signal-handler-parameters
    }
}
