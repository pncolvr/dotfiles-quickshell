pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../"
import "../" as UI

ListView {
    id: root
    property bool blocksPanelShortcuts: true
    property var options: []
    property string selectedName: ""
    property real rowHeight: Theme.controlHeight + Theme.controlSpacing
    property real contentPadding: Theme.controlFieldPadding
    property bool wrapDescriptions: false
    property int descriptionAlignment: Text.AlignLeft
    signal selected(string name)
    model: options
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    function revealSelected() {
        currentIndex = options.findIndex(option => option.name === selectedName && option.available !== false)
        if (currentIndex < 0) navigate(1, true)
        if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
    }
    function navigate(direction, fromEdge = false) {
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
    onSelectedNameChanged: Qt.callLater(revealSelected)
    onOptionsChanged: Qt.callLater(revealSelected)
    Component.onCompleted: Qt.callLater(revealSelected)
    Keys.onPressed: event => {
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
