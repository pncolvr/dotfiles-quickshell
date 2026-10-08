pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../theme/ui" as UI

Item {
    id: root
    required property var entry
    required property Item dragLayer
    property bool current: false
    readonly property Item previewItem: preview
    signal activated()
    signal hovered()
    signal dragStarted()
    signal dragFinished()
    signal dragMoved(real pointerX, real pointerY)
    signal dropCompleted(bool accepted)
    property real pressX: 0
    property real pressY: 0
    property bool dropAccepted: false
    property real dragWidth: 0
    property real dragHeight: 0
    readonly property bool dragging: mouse.drag.active
    onEntryChanged: if (dropAccepted) restoreDrop.restart()
    function resetDrag() {
        body.parent = root
        body.x = 0
        body.y = 0
    }
    Component.onDestruction: resetDrag()
    Timer {
        id: finishDrag
        interval: Theme.exposeDragAnimationDuration
        onTriggered: root.dragFinished()
    }
    Timer {
        id: restoreDrop
        interval: Theme.exposeRearrangeAnimationDuration
        onTriggered: root.dropAccepted = false
    }
    HoverHandler {
        id: hover
        enabled: !root.dropAccepted
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onHoveredChanged: if (hovered) root.hovered()
    }
    Rectangle {
        id: body
        objectName: "exposeDragCard"
        // Keep accepted drops out of the old grid until its model catches up.
        visible: !root.dropAccepted
        transform: Scale {
            origin.x: root.pressX
            origin.y: root.pressY
            xScale: root.dragging ? Math.min(1, Theme.exposeDragWidth / root.dragWidth) : 1
            yScale: xScale
            Behavior on xScale { NumberAnimation { duration: Theme.exposeDragAnimationDuration; easing.type: Easing.OutCubic } }
        }
        width: root.dragging ? root.dragWidth : root.width
        height: root.dragging ? root.dragHeight : root.height
        radius: 0
        color: Theme.alternateBackground
        border.width: root.current || hover.hovered || root.dragging ? 2 : 1
        border.color: root.current || root.dragging ? Theme.accent : Theme.empty
        Drag.active: root.dragging
        Drag.source: root
        Drag.keys: ["quickshell-window"]
        Drag.supportedActions: Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.hotSpot.x: root.pressX
        Drag.hotSpot.y: root.pressY
        WindowPreview {
            id: preview
            objectName: "exposeWindowPreview"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: caption.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Theme.controlSpacing
            anchors.topMargin: 0
            client: root.entry.client
        }
        Rectangle {
            id: caption
            objectName: "exposeWindowCaption"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Theme.controlHeight
            clip: true
            color: Theme.background
            radius: 0
            UI.ColumnText {
                objectName: "exposeWindowName"
                anchors.fill: parent
                anchors.leftMargin: Theme.controlSpacing * 2
                anchors.rightMargin: Theme.controlSpacing * 2
                text: root.entry.title
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !root.dropAccepted
        drag.target: body
        drag.smoothed: false
        onPressed: {
            finishDrag.stop()
            root.dragStarted()
            root.pressX = mouseX
            root.pressY = mouseY
            root.dragWidth = root.width
            root.dragHeight = root.height
            const position = root.mapToItem(root.dragLayer, 0, 0)
            body.parent = root.dragLayer
            body.x = position.x
            body.y = position.y
        }
        onPositionChanged: event => {
            if (!root.dragging) return
            const pointer = mouse.mapToItem(root.dragLayer, event.x, event.y)
            root.dragMoved(pointer.x, pointer.y)
        }
        onReleased: {
            // Drag.drop() can change drag state; remember it before dispatching.
            const wasDragging = root.dragging
            if (wasDragging) {
                root.dropAccepted = body.Drag.drop() === Qt.MoveAction
                root.dropCompleted(root.dropAccepted)
            }
            else root.activated()
            root.resetDrag()
            if (wasDragging) finishDrag.restart()
            else root.dragFinished()
        }
        onCanceled: {
            body.Drag.cancel()
            root.dropCompleted(false)
            root.resetDrag()
            finishDrag.restart()
        }
    }
}
