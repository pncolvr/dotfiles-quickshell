pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../theme/ui" as UI

Rectangle {
    id: root
    required property var workspace
    property bool current: false
    property var picker
    readonly property var windows: picker.items.filter(entry => entry.workspaceId === workspace.id).map(entry => entry.client).sort((a, b) => (b.focusHistoryID ?? 0) - (a.focusHistoryID ?? 0))
    readonly property var bounds: {
        if (!windows.length) return {left: 0, top: 0, width: 1, height: 1}
        const left = Math.min(...windows.map(window => window.at?.[0] ?? 0))
        const top = Math.min(...windows.map(window => window.at?.[1] ?? 0))
        const right = Math.max(...windows.map(window => (window.at?.[0] ?? 0) + (window.size?.[0] ?? 1)))
        const bottom = Math.max(...windows.map(window => (window.at?.[1] ?? 0) + (window.size?.[1] ?? 1)))
        return {left, top, width: Math.max(1, right - left), height: Math.max(1, bottom - top)}
    }
    readonly property bool dropHovered: drop.containsDrag
    color: dropHovered ? Theme.accent : current || hover.hovered ? Theme.alternateBackground : Theme.background
    radius: Theme.iconButtonRadius
    border.width: dropHovered || current ? 2 : 1
    border.color: dropHovered || current ? Theme.accent : Theme.empty
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: root.picker.selectExposeWorkspace(root.workspace.id) }
    UI.IconText {
        objectName: "exposeWorkspaceIcon"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.controlSpacing
        centerVertical: false
        text: Theme.workspaceIcons[root.workspace.id - 1] ?? Theme.workspaceUnknownIcon
        font.pixelSize: Theme.exposeWorkspaceIconSize
        color: root.dropHovered ? Theme.background : root.current ? Theme.accent : Theme.inactive
    }
    UI.ColumnText {
        objectName: "exposeWorkspaceName"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.exposeWorkspaceIconSize + Theme.controlSpacing * 2
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
        y: Theme.exposeWorkspaceHeight
        width: parent.width - x * 2
        height: Theme.exposeWorkspacePreviewHeight
        clip: true
        readonly property real previewScale: Math.min(width / root.bounds.width, height / root.bounds.height)
        Repeater {
            model: root.windows
            WindowPreview {
                required property var modelData
                client: modelData
                x: (desktop.width - root.bounds.width * desktop.previewScale) / 2 + ((modelData.at?.[0] ?? 0) - root.bounds.left) * desktop.previewScale
                y: (desktop.height - root.bounds.height * desktop.previewScale) / 2 + ((modelData.at?.[1] ?? 0) - root.bounds.top) * desktop.previewScale
                width: Math.max(2, (modelData.size?.[0] ?? 1) * desktop.previewScale)
                height: Math.max(2, (modelData.size?.[1] ?? 1) * desktop.previewScale)
                border.width: 1
                border.color: root.dropHovered ? Theme.background : Theme.empty
            }
        }
    }
    DropArea {
        id: drop
        objectName: "exposeDropWorkspace-" + root.workspace.id
        anchors.fill: parent
        keys: ["quickshell-window"]
        onDropped: event => {
            const card = event.source as ExposeWindowCard
            if (card && root.picker.moveExposeWindow(card.entry.id, root.workspace.id)) event.acceptProposedAction()
        }
    }
}
