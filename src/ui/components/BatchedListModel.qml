import QtQuick

ListModel {
    id: root
    // Append rows without resetting delegates already on screen.
    dynamicRoles: true
    property var items: []
    property int batchSize: 3
    property bool initialized: false
    readonly property bool loading: count < items.length

    function appendBatch() {
        const end = Math.min(items.length, count + Math.max(1, batchSize))
        for (let index = count; index < end; index++) append({value: items[index]})
    }

    function synchronize() {
        if (!initialized) return
        if (count > items.length) remove(items.length, count - items.length)
        for (let index = 0; index < count; index++) set(index, {value: items[index]})
        appendBatch()
    }

    onItemsChanged: synchronize()
    Component.onCompleted: { initialized = true; synchronize() }

    property FrameAnimation builder: FrameAnimation {
        running: root.initialized && root.loading
        onTriggered: root.appendBatch()
    }
}
