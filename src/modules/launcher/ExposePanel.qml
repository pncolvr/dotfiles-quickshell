pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI

FocusScope {
    id: root
    required property var picker
    function focusSearch() { search.forceActiveFocus() }
    Component.onCompleted: Qt.callLater(root.focusSearch)
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        switch (event.key) {
            case Qt.Key_Escape: root.picker.close(); break
            case Qt.Key_Left: root.picker.move(-1); break
            case Qt.Key_Right: root.picker.move(1); break
            case Qt.Key_Up: root.picker.move(-grid.columns); break
            case Qt.Key_Down: root.picker.move(grid.columns); break
            case Qt.Key_Return:
            case Qt.Key_Enter: root.picker.accept(false, false); break
            default: event.accepted = false; return
        }
        event.accepted = true
    }
    Item {
        id: workspaces
        width: Math.min(parent.width, all.width + Theme.controlSpacing + root.picker.exposeWorkspaces.length * (Theme.exposeWorkspaceWidth + Theme.controlSpacing) - Theme.controlSpacing)
        anchors.horizontalCenter: parent.horizontalCenter
        height: Theme.exposeWorkspaceHeight + Theme.exposeWorkspacePreviewHeight + Theme.controlSpacing * 2
        UI.ActionButton {
            id: all
            objectName: "exposeAllWorkspaces"
            width: 96
            height: workspaces.height
            label: "Show all"
            foreground: root.picker.exposeWorkspace === 0 ? Theme.accent : Theme.inactive
            fillColor: Theme.background
            onClicked: { root.picker.selectExposeWorkspace(0); root.focusSearch() }
        }
        ListView {
            id: strip
            objectName: "exposeWorkspaces"
            anchors.left: all.right
            anchors.leftMargin: Theme.controlSpacing
            anchors.right: parent.right
            height: parent.height
            orientation: ListView.Horizontal
            model: root.picker.exposeWorkspaces
            spacing: Theme.controlSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: WorkspacePreview {
                required property var modelData
                workspace: modelData
                picker: root.picker
                width: Theme.exposeWorkspaceWidth
                height: strip.height
                current: root.picker.exposeWorkspace === modelData.id
            }
            QC.ScrollBar.horizontal: UI.ScrollBar {}
            WheelHandler {
                target: null
                onWheel: event => {
                    strip.contentX = Math.max(0, Math.min(Math.max(0, strip.contentWidth - strip.width), strip.contentX
                        - (event.pixelDelta.x || event.pixelDelta.y || (event.angleDelta.x || event.angleDelta.y) / 120 * 40)))
                    event.accepted = true
                }
            }
        }
    }
    UI.SearchField {
        id: search
        objectName: "exposeSearch"
        y: workspaces.height + Theme.exposeSpacing
        width: parent.width
        placeholderText: "Search windows"
        pauseTooltipDismissal: false
        resetWithTooltip: false
        handleEscape: false
        onTextChanged: root.picker.query = text
        Keys.priority: Keys.BeforeItem
        Keys.forwardTo: [root]
    }
    GridView {
        id: grid
        objectName: "exposeWindows"
        y: search.y + search.height + Theme.exposeSpacing
        width: parent.width
        height: Math.max(0, footer.y - y - Theme.exposeSpacing)
        readonly property int columns: {
            const maximum = Math.max(1, Math.floor(width / Theme.exposeCardMinWidth))
            let result = Math.min(maximum, Math.max(1, Math.ceil(Math.sqrt(count * width / Math.max(1, height) * 9 / 16))))
            while (result < maximum && Math.ceil(count / result) * (width / result * 9 / 16 + Theme.controlHeight + Theme.exposeSpacing) > height) result++
            return result
        }
        cellWidth: width / columns
        cellHeight: cellWidth * 9 / 16 + Theme.controlHeight + Theme.exposeSpacing
        clip: true
        model: root.picker.filteredItems
        currentIndex: root.picker.currentIndex
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)
        delegate: ExposeWindowCard {
            required property var modelData
            required property int index
            objectName: "exposeWindow-" + modelData.id
            entry: modelData
            width: grid.cellWidth - Theme.exposeSpacing
            height: grid.cellHeight - Theme.exposeSpacing
            current: root.picker.currentIndex === index
            dragLayer: dragOverlay
            onHovered: if (!root.picker.exposeDragging) root.picker.select(index, false)
            onActivated: { root.picker.select(index, false); root.picker.accept(false, false) }
            onDragStarted: root.picker.exposeDragging = true
            onDragFinished: root.picker.exposeDragging = false
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
    }
    UI.ColumnText {
        anchors.centerIn: grid
        visible: grid.count === 0
        text: search.text ? "No matching windows" : "No windows in this workspace"
        color: Theme.inactive
    }
    UI.ColumnText {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        text: root.picker.filteredItems.length + " windows · Arrows to select · Enter to focus · Drag to a workspace"
        color: Theme.inactive
        elide: Text.ElideRight
    }
    Item { id: dragOverlay; anchors.fill: parent; z: 100 }
}
