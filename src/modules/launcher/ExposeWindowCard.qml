pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../theme/ui" as UI

Item {
    id: root
    required property var entry
    required property Item dragLayer
    property bool current: false
    signal activated()
    signal hovered()
    signal dragStarted()
    signal dragFinished()
    property real pressX: 0
    property real pressY: 0
    readonly property bool dragging: mouse.drag.active
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
    HoverHandler {
        id: hover
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onHoveredChanged: if (hovered) root.hovered()
    }
    Rectangle {
        id: body
        objectName: "exposeDragCard"
        transform: Scale {
            origin.x: root.pressX
            origin.y: root.pressY
            xScale: root.dragging ? Math.min(1, Theme.exposeDragWidth / root.width) : 1
            yScale: xScale
            Behavior on xScale { NumberAnimation { duration: Theme.exposeDragAnimationDuration; easing.type: Easing.OutCubic } }
        }
        width: root.width
        height: root.height
        radius: Theme.tooltipRadius
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
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.controlSpacing
            height: Math.max(0, parent.height - caption.height - Theme.controlSpacing * 3)
            client: root.entry.client
        }
        Rectangle {
            id: caption
            objectName: "exposeWindowCaption"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: Theme.controlHeight
            color: Theme.background
            radius: Theme.tooltipRadius
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
        drag.target: body
        onPressed: {
            finishDrag.stop()
            root.dragStarted()
            root.pressX = mouseX
            root.pressY = mouseY
            const position = root.mapToItem(root.dragLayer, 0, 0)
            body.parent = root.dragLayer
            body.x = position.x
            body.y = position.y
        }
        onReleased: {
            if (root.dragging) body.Drag.drop()
            else root.activated()
            root.resetDrag()
            if (root.dragging) finishDrag.restart()
            else root.dragFinished()
        }
        onCanceled: { body.Drag.cancel(); root.resetDrag(); finishDrag.restart() }
    }
}
