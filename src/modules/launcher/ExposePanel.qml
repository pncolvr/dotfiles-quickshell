pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI

FocusScope {
    id: root
    required property var picker
    readonly property real workspaceScale: Math.max(0.72, Math.min(1, width / 1920, height / 1080))
    readonly property real workspaceWidth: Math.round(Theme.exposeWorkspaceWidth * workspaceScale)
    readonly property real searchWidth: Math.min(Theme.exposeSearchWidth, Math.max(140, width * 0.18))
    function focusSearch() { search.forceActiveFocus() }
    Component.onCompleted: Qt.callLater(root.focusSearch)
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        switch (event.key) {
            case Qt.Key_Escape: root.picker.close(); break
            case Qt.Key_Left: root.picker.move(-1); break
            case Qt.Key_Right: root.picker.move(1); break
            case Qt.Key_Up: grid.moveVertical(-1); break
            case Qt.Key_Down: grid.moveVertical(1); break
            case Qt.Key_Return:
            case Qt.Key_Enter: root.picker.accept(false, false); break
            default: event.accepted = false; return
        }
        event.accepted = true
    }
    Item {
        id: workspaces
        y: controls.height + Theme.controlSpacing
        width: Math.max(0, Math.min(parent.width,
            root.picker.exposeWorkspaces.length * (root.workspaceWidth + Theme.controlSpacing) - Theme.controlSpacing))
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.round((Theme.exposeWorkspaceHeight + Theme.exposeWorkspacePreviewHeight) * root.workspaceScale) + Theme.controlSpacing * 2
        ListView {
            id: strip
            objectName: "exposeWorkspaces"
            anchors.fill: parent
            orientation: ListView.Horizontal
            model: root.picker.exposeWorkspaces
            spacing: Theme.controlSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: WorkspacePreview {
                required property var modelData
                workspace: modelData
                picker: root.picker
                sizeScale: root.workspaceScale
                width: root.workspaceWidth
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
    Item {
        id: controls
        anchors.horizontalCenter: parent.horizontalCenter
        width: search.width + Theme.controlSpacing + all.width
        height: Math.max(search.height, all.height)
        UI.SearchField {
            id: search
            objectName: "exposeSearch"
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: root.searchWidth
            placeholderText: "Search windows"
            pauseTooltipDismissal: false
            resetWithTooltip: false
            handleEscape: false
            onTextChanged: root.picker.query = text
            Keys.priority: Keys.BeforeItem
            Keys.forwardTo: [root]
        }
        UI.ActionButton {
            id: all
            objectName: "exposeAllWorkspaces"
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 96
            label: "Show all"
            foreground: root.picker.exposeWorkspace === 0 ? Theme.accent : Theme.inactive
            fillColor: Theme.background
            onClicked: { root.picker.selectExposeWorkspace(0); root.focusSearch() }
        }
    }
    ExposeWindowGrid {
        id: grid
        objectName: "exposeWindows"
        picker: root.picker
        dragLayer: dragOverlay
        y: workspaces.y + workspaces.height + Theme.exposeSpacing
        width: parent.width
        height: Math.max(0, footer.y - y - Theme.exposeSpacing)
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
