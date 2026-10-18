pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import ".." as UI

ListView {
    id: root
    property bool blocksPanelShortcuts: true
    property var cancelHandler: null
    property var options: []
    property var modelOptions: []
    property int viewportGeneration: 0
    property string selectedName: ""
    property real rowHeight: Theme.controlHeight + Theme.controlSpacing
    property real contentPadding: Theme.controlFieldPadding
    property bool wrapDescriptions: false
    property int descriptionAlignment: Text.AlignLeft
    signal selected(string name)
    model: modelOptions
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    function revealSelected() {
        viewportGeneration++
        currentIndex = options.findIndex(option => option.name === selectedName && option.available !== false)
        if (currentIndex < 0) navigate(1, true)
        if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
    }
    function synchronizeOptions() {
        // Polling services publish fresh objects even when the choices are unchanged.
        const next = options.map(option => ({name:option.name, description:option.description, available:option.available !== false}))
        if (next.length === modelOptions.length && next.every((option,index) => {
            const previous = modelOptions[index]
            return option.name === previous.name && option.description === previous.description && option.available === previous.available
        })) return
        const currentName = modelOptions[currentIndex]?.name
        const previousY = contentY
        const preserveViewport = modelOptions.length > 0
        const generation = ++viewportGeneration
        modelOptions = next
        if (!preserveViewport) { reveal.restart(); return }
        currentIndex = next.findIndex(option => option.name === currentName && option.available)
        if (currentIndex < 0) currentIndex = next.findIndex(option => option.name === selectedName && option.available)
        Qt.callLater(() => {
            if (generation !== root.viewportGeneration) return
            root.contentY = Math.max(root.originY, Math.min(previousY, root.originY + Math.max(0,root.contentHeight - root.height)))
        })
    }
    function navigate(direction, fromEdge = false) {
        viewportGeneration++
        let next = fromEdge ? (direction > 0 ? 0 : options.length - 1) : currentIndex + direction
        while (next >= 0 && next < options.length) {
            if (options[next].available !== false) {
                currentIndex = next
                positionViewAtIndex(next, ListView.Contain)
                return
            }
            next += direction
        }
    }
    function activateCurrent() {
        const option = options[currentIndex]
        if (option && option.available !== false) selected(option.name)
    }
    // Keep deferred selection work owned by this view so closing its form
    // cancels it instead of invoking methods on a destroyed QML context.
    Timer { id: reveal; interval: 0; onTriggered: root.revealSelected() }
    onSelectedNameChanged: reveal.restart()
    onOptionsChanged: synchronizeOptions()
    Component.onCompleted: { synchronizeOptions(); reveal.restart() }
    Keys.onPressed: event => {
        if (root.cancelHandler && UI.Keybinds.handleCancel(event, root.cancelHandler)) return
        if (event.key === Qt.Key_Down) navigate(1)
        else if (event.key === Qt.Key_Up) navigate(-1)
        else if (event.key === Qt.Key_Home) navigate(1, true)
        else if (event.key === Qt.Key_End) navigate(-1, true)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) activateCurrent()
        else return
        event.accepted = true
    }
    delegate: UI.SelectionRow {
        required property var modelData
        required property int index
        width: root.width
        height: root.rowHeight
        padding: root.contentPadding
        description: modelData.description
        selected: modelData.name === root.selectedName
        highlighted: root.activeFocus && root.currentIndex === index
        wrapDescription: root.wrapDescriptions
        descriptionAlignment: root.descriptionAlignment
        enabled: modelData.available !== false
        activeFocusOnTab: false
        onClicked: { root.currentIndex = index; root.selected(modelData.name) }
    }
    QC.ScrollBar.vertical: UI.ScrollBar {}
}
