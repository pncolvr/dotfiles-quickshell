import Quickshell
import "../"
import "../../config"

// Common collection/draft lifecycle. Each feature owns dispatch and record validation.
Singleton {
    id: root
    required property var repository
    required property int pickerMode
    required property string collectionName
    required property var itemForEntry
    property bool managing: false
    property bool showAll: false
    property bool activeOnly: false
    property string acceptLabel: 'Open'
    property var draft: null
    property string error: ''
    property bool busy: false
    property var activeEntryIds: []
    property var activeFilterIds: activeEntryIds
    readonly property var entries: repository.entries
    readonly property var availableEntries: entries.filter(entry => (!activeOnly || activeFilterIds.includes(entry.id)) &&
        (activeEntryIds.includes(entry.id) || (entry.enabled &&
            (showAll || entry.category !== 'work' || StatusService.status === Config.pickerWorkStatus))))
    signal saved()
    function open() {
        managing=false; showAll=false; activeOnly=false; draft=null; error=''
        if (!repository.reload()) error=repository.error
        syncPicker()
    }
    function syncPicker() {
        if (PickerService.mode !== pickerMode) return
        const previous=PickerService.currentItem?.id
        PickerService.items=availableEntries.map(itemForEntry)
        PickerService.currentIndex=Math.max(0,PickerService.filteredItems.findIndex(row => row.id===previous))
        PickerService.acceptLabel=acceptLabel; PickerService.error=error
    }
    function setManaging(value) { managing=value; cancel(); if (!value) { syncPicker(); PickerService.opened() } }
    function toggleActiveOnly() { activeOnly=!activeOnly; PickerService.opened() }
    function toggleShowAll() { showAll=!showAll; syncPicker(); PickerService.opened() }
    function edit(entry) { draft=Object.assign({},entry); error='' }
    function cancel() { draft=null; error='' }
    function save(value) {
        if (busy || !value) return
        value.id=draft?.id ?? ''
        if (!repository.save(value)) { error=repository.error; return }
        draft=null; error=''; saved()
    }
    function remove(id) { if (!repository.remove(id)) error=repository.error }
    onAcceptLabelChanged: if (PickerService.mode===pickerMode) PickerService.acceptLabel=acceptLabel
    onAvailableEntriesChanged: syncPicker()
    onErrorChanged: syncPicker()
}
