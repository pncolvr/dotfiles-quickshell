pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../theme/ui" as UI

FocusScope {
    id: root
    required property var picker
    property real transitionProgress: 1
    property string captureAddress: ""
    property bool animationsEnabled: true
    readonly property int workspaceCount: picker.exposeWorkspaces.length
    readonly property real workspaceSpacing: Math.min(Theme.controlSpacing, width / Math.max(1, workspaceCount * 4))
    readonly property real workspaceScale: Math.max(0, Math.min(1, width / 1920, height / 1080,
        (width - Math.max(0, workspaceCount - 1) * workspaceSpacing) / Math.max(1, workspaceCount) / Theme.exposeWorkspaceWidth))
    readonly property real workspaceWidth: Math.max(1, Math.floor(Theme.exposeWorkspaceWidth * workspaceScale))
    readonly property real searchWidth: Math.min(Theme.exposeSearchWidth, Math.max(140, width * 0.18))
    function focusSearch() { search.forceActiveFocus() }
    function workspaceForKey(event) {
        // Use physical number-row keys when Shift changes digits into punctuation.
        if (event.nativeScanCode >= 10 && event.nativeScanCode <= 19) return event.nativeScanCode - 9
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) return event.key === Qt.Key_0 ? 10 : event.key - Qt.Key_0
        return 0
    }
    function windowPreviewRect(address) {
        grid.finishWorkspaceTransition()
        const index = picker.filteredItems.findIndex(entry => entry.id === address)
        const card = grid.itemAtIndex(index) as ExposeWindowCard
        if (!card) return null
        const preview = card.previewItem
        const position = preview.mapToItem(grid, 0, 0)
        // Off-screen previews use their workspace miniature as the zoom target.
        if (position.x < 0 || position.y < 0 || position.x + preview.width > grid.width + 1
            || position.y + preview.height > grid.height + 1) return null
        const point = preview.mapToItem(root, 0, 0)
        return Qt.rect(point.x, point.y, preview.width, preview.height)
    }
    function workspacePreviewRect(workspace) {
        grid.finishWorkspaceTransition()
        const index = picker.exposeWorkspaces.findIndex(entry => entry.id === workspace)
        const tile = strip.itemAtIndex(index) as WorkspacePreview
        if (!tile) return null
        const preview = tile.previewItem
        const point = preview.mapToItem(root, 0, 0)
        return Qt.rect(point.x, point.y, preview.width, preview.height)
    }

    Component.onCompleted: Qt.callLater(root.focusSearch)
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        const modifiers = event.modifiers & ~Qt.KeypadModifier
        if (modifiers === Qt.ControlModifier && event.key === Qt.Key_A) {
            if (!event.isAutoRepeat) root.picker.toggleExposeAll()
            root.focusSearch()
            event.accepted = true
            return
        }
        if (modifiers === Qt.ControlModifier || modifiers === (Qt.ControlModifier | Qt.ShiftModifier)) {
            const workspace = root.workspaceForKey(event)
            if (workspace) {
                if (root.picker.exposeWorkspaces.some(entry => entry.id === workspace)) {
                    if (modifiers & Qt.ShiftModifier) {
                        const selected = root.picker.currentItem
                        if (selected && !event.isAutoRepeat) root.picker.moveExposeWindow(selected.id, workspace)
                    } else {
                        root.picker.selectExposeWorkspace(workspace)
                        root.focusSearch()
                    }
                }
                event.accepted = true
                return
            }
        }
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
        y: controls.height + Theme.exposeSpacing
        width: Math.max(0, Math.min(parent.width,
            root.picker.exposeWorkspaces.length * (root.workspaceWidth + root.workspaceSpacing) - root.workspaceSpacing))
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.round((Theme.exposeWorkspaceHeight + Theme.exposeWorkspacePreviewHeight) * root.workspaceScale) + Theme.controlSpacing * 2
        ListView {
            id: strip
            objectName: "exposeWorkspaces"
            anchors.fill: parent
            orientation: ListView.Horizontal
            interactive: false
            contentX: 0
            model: root.picker.exposeWorkspaces
            spacing: root.workspaceSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: WorkspacePreview {
                required property var modelData
                workspace: modelData
                picker: root.picker
                sizeScale: root.workspaceScale
                animationsEnabled: root.animationsEnabled
                width: root.workspaceWidth
                height: strip.height
                current: root.picker.exposeWorkspace === modelData.id
            }
        }
    }
    Item {
        id: controls
        anchors.horizontalCenter: parent.horizontalCenter
        width: search.width
        height: search.height
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
    }
    ExposeWindowGrid {
        id: grid
        objectName: "exposeWindows"
        picker: root.picker
        transitionProgress: root.transitionProgress
        captureAddress: root.captureAddress
        animationsEnabled: root.animationsEnabled
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
