pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../theme/ui" as UI

Rectangle {
    id: root
    required property var workspace
    property bool current: false
    property real sizeScale: 1
    property bool animationsEnabled: true
    readonly property Item previewItem: desktop
    property var picker
    property var hoveredEntry: null
    property var previewWindows: []
    property bool modelReady: false
    property bool previewReady: false
    readonly property var windows: {
        const pending = picker.exposePendingMoves ?? {}
        const entries = picker.items.filter(entry => (pending[entry.id] ?? entry.workspaceId) === workspace.id)
        if (hoveredEntry && !entries.some(entry => entry.id === hoveredEntry.id)) entries.push(hoveredEntry)
        return entries.map(entry => entry.client).sort((a, b) => (b.focusHistoryID ?? 0) - (a.focusHistoryID ?? 0))
    }
    readonly property var bounds: {
        if (!previewWindows.length) return {left: 0, top: 0, width: 1, height: 1}
        const left = Math.min(...previewWindows.map(window => window.at?.[0] ?? 0))
        const top = Math.min(...previewWindows.map(window => window.at?.[1] ?? 0))
        const right = Math.max(...previewWindows.map(window => (window.at?.[0] ?? 0) + (window.size?.[0] ?? 1)))
        const bottom = Math.max(...previewWindows.map(window => (window.at?.[1] ?? 0) + (window.size?.[1] ?? 1)))
        return {left, top, width: Math.max(1, right - left), height: Math.max(1, bottom - top)}
    }
    function synchronizeWindows() {
        if (!modelReady) return
        // Keep the old capture alive until its fade back to the empty placeholder finishes.
        if (!windows.length && previewReady && animationsEnabled && windowModel.count) {
            retirePreview.restart()
            return
        }
        retirePreview.stop()
        previewWindows = windows
        const addresses = new Set(windows.map(window => window.address))
        for (let index = windowModel.count - 1; index >= 0; index--) {
            if (!addresses.has(windowModel.get(index).address)) windowModel.remove(index)
        }
        windows.forEach((window, index) => {
            let previous = index
            while (previous < windowModel.count && windowModel.get(previous).address !== window.address) previous++
            if (previous === windowModel.count) windowModel.insert(index, {address: window.address, value: window})
            else {
                if (previous !== index) windowModel.move(previous, index, 1)
                windowModel.setProperty(index, "value", window)
            }
        })
    }
    onWindowsChanged: synchronizeWindows()
    Component.onCompleted: {
        modelReady = true
        synchronizeWindows()
        Qt.callLater(() => root.previewReady = true)
    }
    ListModel { id: windowModel; dynamicRoles: true }
    Timer {
        id: retirePreview
        interval: Theme.exposeRearrangeAnimationDuration
        onTriggered: if (!root.windows.length) { windowModel.clear(); root.previewWindows = [] }
    }
    readonly property bool dropHovered: drop.containsDrag
    color: dropHovered ? Theme.accent : current || hover.hovered ? Theme.alternateBackground : Theme.background
    radius: Theme.iconButtonRadius
    border.width: dropHovered || current ? 2 : 1
    border.color: dropHovered || current ? Theme.accent : Theme.empty
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: root.picker.selectExposeWorkspace(root.workspace.id) }
    UI.IconText {
        id: icon
        objectName: "exposeWorkspaceIcon"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(Theme.exposeWorkspaceTopPadding * root.sizeScale)
        centerVertical: false
        text: Theme.workspaceIcons[root.workspace.id - 1] ?? Theme.workspaceUnknownIcon
        font.pixelSize: Math.round(Theme.exposeWorkspaceIconSize * root.sizeScale)
        color: root.dropHovered ? Theme.background : root.current ? Theme.accent : Theme.inactive
    }
    UI.ColumnText {
        id: name
        objectName: "exposeWorkspaceName"
        anchors.horizontalCenter: parent.horizontalCenter
        y: icon.y + icon.height + Theme.controlSpacing
        width: Math.max(0, Math.min(implicitWidth, root.width - Theme.controlSpacing * 2))
        text: root.workspace.name
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.dropHovered ? Theme.background : root.current ? Theme.accent : Theme.inactive
        UI.HoverTooltip { text: root.workspace.name }
    }
    Item {
        id: desktop
        objectName: "exposeWorkspaceLayout"
        x: Theme.controlSpacing
        y: Math.max(Math.round(Theme.exposeWorkspaceHeight * root.sizeScale), name.y + name.height + Theme.controlSpacing)
        width: parent.width - x * 2
        height: Math.max(0, root.height - y - Theme.controlSpacing * 2)
        clip: true
        readonly property real previewScale: Math.min(width / root.bounds.width, height / root.bounds.height)
        UI.IconText {
            objectName: "exposeEmptyWorkspaceIcon"
            anchors.centerIn: parent
            text: Theme.exposeIcon
            color: root.dropHovered ? Theme.background : Theme.inactive
            font.pixelSize: Math.min(32, desktop.height * 0.6, desktop.width * 0.5)
            opacity: 1 - miniatures.opacity
            visible: opacity > 0
        }
        Item {
            id: miniatures
            objectName: "exposeWorkspaceWindows"
            anchors.fill: parent
            opacity: root.windows.length ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: root.previewReady && root.animationsEnabled
                NumberAnimation { duration: Theme.exposeRearrangeAnimationDuration; easing.type: Easing.OutCubic }
            }
            Repeater {
                model: windowModel
                WindowPreview {
                    id: miniature
                    required property var value
                    property bool geometryReady: false
                    Component.onCompleted: Qt.callLater(() => miniature.geometryReady = true)
                    objectName: "exposeWorkspaceWindow-" + value.address
                    client: value
                    x: (desktop.width - root.bounds.width * desktop.previewScale) / 2 + ((value.at?.[0] ?? 0) - root.bounds.left) * desktop.previewScale
                    y: (desktop.height - root.bounds.height * desktop.previewScale) / 2 + ((value.at?.[1] ?? 0) - root.bounds.top) * desktop.previewScale
                    width: Math.max(2, (value.size?.[0] ?? 1) * desktop.previewScale)
                    height: Math.max(2, (value.size?.[1] ?? 1) * desktop.previewScale)
                    border.width: 1
                    border.color: root.dropHovered ? Theme.background : Theme.empty
                    Behavior on x {
                        enabled: miniature.geometryReady && root.animationsEnabled
                        NumberAnimation { duration: Theme.exposeRearrangeAnimationDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: miniature.geometryReady && root.animationsEnabled
                        NumberAnimation { duration: Theme.exposeRearrangeAnimationDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on width {
                        enabled: miniature.geometryReady && root.animationsEnabled
                        NumberAnimation { duration: Theme.exposeRearrangeAnimationDuration; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        enabled: miniature.geometryReady && root.animationsEnabled
                        NumberAnimation { duration: Theme.exposeRearrangeAnimationDuration; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
    DropArea {
        id: drop
        objectName: "exposeDropWorkspace-" + root.workspace.id
        anchors.fill: parent
        keys: ["quickshell-window"]
        onEntered: event => {
            const card = event.source as ExposeWindowCard
            root.hoveredEntry = card && card.entry.workspaceId !== root.workspace.id ? card.entry : null
        }
        onExited: root.hoveredEntry = null
        onDropped: event => {
            const card = event.source as ExposeWindowCard
            if (card && root.picker.moveExposeWindow(card.entry.id, root.workspace.id)) event.acceptProposedAction()
            root.hoveredEntry = null
        }
    }
}
