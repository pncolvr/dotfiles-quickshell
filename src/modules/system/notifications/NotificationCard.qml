pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Controls as QC
import Quickshell
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Rectangle {
    id: root
    required property var entry
    property bool popup: false
    property real clockNow: Date.now()
    property var hoveredEntry: null
    readonly property var timerEntry: {
        const live = NotificationService.liveEntries
        return NotificationService.liveFor(root.entry) ?? root.entry
    }
    readonly property bool timerPaused: timerEntry.deadline < 0
    readonly property real countdownProgress: root.popup && timerEntry.duration > 0
        ? Math.max(0, Math.min(1, (timerPaused ? -timerEntry.deadline : timerEntry.deadline - clockNow) / timerEntry.duration)) : 1
    function updateHover() {
        clockNow = Date.now()
        const next = popup && popupHover?.hovered ? entry : null
        if (hoveredEntry?.liveId !== next?.liveId) {
            if (hoveredEntry) NotificationService.setPopupHovered(hoveredEntry, false)
            hoveredEntry = next
        }
        if (next) NotificationService.setPopupHovered(next, true)
    }
    onEntryChanged: updateHover()
    onPopupChanged: updateHover()
    Component.onDestruction: if (hoveredEntry) NotificationService.setPopupHovered(hoveredEntry, false)
    readonly property var emitter: NotificationEmitterRepository.emitters[entry.emitterKey]
    readonly property string notificationImage: root.entry.image || NotificationService.liveFor(root.entry)?.image || ""
    readonly property string appIcon: root.emitter?.icon || DesktopEntries.byId(root.emitter?.desktopEntry || "")?.icon || ""
    readonly property bool hasExtraImage: root.appIcon.length > 0 && root.notificationImage.length > 0
    // notify-send sends file icons as notification images rather than appIcon.
    readonly property bool usesImageAsIcon: !root.appIcon && root.notificationImage.length > 0
    readonly property color urgencyColor: root.entry.urgency === 2 ? Theme.notificationCritical : root.entry.urgency === 0 ? Theme.inactive : Theme.accent
    readonly property real urgencyLineWidth: root.entry.urgency === 2 ? 5 : 2
    readonly property string iconSource: {
        if (root.usesImageAsIcon) return root.notificationImage
        const icon = root.appIcon || "dialog-information"
        return /^(file:|image:|data:)/.test(icon) ? icon : icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, true)
    }
    readonly property var displayActions: {
        if (!root.popup) return []
        const live = NotificationService.liveEntries
        return NotificationService.actions(root.entry, false)
    }
    implicitHeight: layout.height + 28
    radius: Theme.notificationRadius
    color: popup ? Theme.notificationBackground : Theme.alternateBackground
    border.color: popup ? Theme.notificationBorder : urgencyColor
    border.width: popup ? 1 : urgencyLineWidth

    HoverHandler {
        id: popupHover
        enabled: root.popup
        onHoveredChanged: root.updateHover()
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                NotificationService.dismiss(root.entry, !root.popup)
            else
                NotificationService.activate(root.entry)
        }
    }
    Shape {
        id: countdownOutline
        objectName: "notificationOutline"
        anchors.fill: parent
        visible: root.popup && root.countdownProgress > 0
        preferredRendererType: Shape.CurveRenderer
        readonly property real lineWidth: root.urgencyLineWidth
        readonly property real inset: lineWidth / 2
        readonly property real curveRadius: Math.max(0, Math.min(root.radius - inset, width / 2 - inset, height / 2 - inset))
        ShapePath {
            strokeColor: root.urgencyColor
            strokeWidth: countdownOutline.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            // The path starts/ends at bottom center; both trimmed ends approach top center.
            trim.start: (1 - root.countdownProgress) / 2
            trim.end: (1 + root.countdownProgress) / 2
            startX: countdownOutline.width / 2
            startY: countdownOutline.height - countdownOutline.inset
            PathLine {
                x: countdownOutline.width - countdownOutline.inset - countdownOutline.curveRadius
                y: countdownOutline.height - countdownOutline.inset
            }
            PathArc {
                x: countdownOutline.width - countdownOutline.inset
                y: countdownOutline.height - countdownOutline.inset - countdownOutline.curveRadius
                radiusX: countdownOutline.curveRadius
                radiusY: radiusX
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: countdownOutline.width - countdownOutline.inset
                y: countdownOutline.inset + countdownOutline.curveRadius
            }
            PathArc {
                x: countdownOutline.width - countdownOutline.inset - countdownOutline.curveRadius
                y: countdownOutline.inset
                radiusX: countdownOutline.curveRadius
                radiusY: radiusX
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: countdownOutline.inset + countdownOutline.curveRadius
                y: countdownOutline.inset
            }
            PathArc {
                x: countdownOutline.inset
                y: countdownOutline.inset + countdownOutline.curveRadius
                radiusX: countdownOutline.curveRadius
                radiusY: radiusX
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: countdownOutline.inset
                y: countdownOutline.height - countdownOutline.inset - countdownOutline.curveRadius
            }
            PathArc {
                x: countdownOutline.inset + countdownOutline.curveRadius
                y: countdownOutline.height - countdownOutline.inset
                radiusX: countdownOutline.curveRadius
                radiusY: radiusX
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: countdownOutline.width / 2
                y: countdownOutline.height - countdownOutline.inset
            }
        }
    }
    FrameAnimation {
        running: root.popup && root.visible && !root.timerPaused && root.timerEntry.duration > 0 && root.countdownProgress > 0
        onTriggered: root.clockNow = Date.now()
    }
    Row {
        id: layout
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 12
        Item {
            id: iconColumn
            width: root.hasExtraImage ? 48 : 40
            height: width
            Image {
                width: 40
                height: 40
                source: root.iconSource
                // Qt applies the screen's pixel ratio to icon-provider requests.
                sourceSize: root.iconSource.startsWith("image://icon/") ? Qt.size(width, height) : undefined
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
            NotificationAvatar {
                x: root.hasExtraImage ? 8 : 0
                y: x
                width: 40
                height: 40
                source: root.hasExtraImage ? root.notificationImage : ""
                visible: root.hasExtraImage && status !== Image.Error
            }
        }
        Column {
            id: contents
            width: parent.width - iconColumn.width - parent.spacing
            spacing: 8
            Item {
                width: parent.width
                height: Math.max(headingText.height, dismissButton.height - contents.spacing)
                Column {
                    id: headingText
                    width: parent.width - dismissButton.width - 8
                    spacing: 0
                    Row {
                        width: parent.width
                        spacing: 8
                        UI.Text {
                            centerVertical: false
                            width: Math.min(implicitWidth, Math.max(0, parent.width - (timestamp.visible ? timestamp.implicitWidth + parent.spacing : 0)))
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.emitter?.name || "Unknown application"
                            elide: Text.ElideRight
                            color: Theme.inactive
                            font.family: root.popup ? Theme.notificationFont : Theme.fontFamily
                            textFormat: Text.PlainText
                        }
                        UI.Text {
                            id: timestamp
                            visible: !root.popup
                            centerVertical: false
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDateTime(new Date(root.entry.updatedAt), "yyyy-MM-dd hh:mm:ss")
                            color: Theme.inactive
                            font.pixelSize: 10
                        }
                    }
                    UI.Text {
                        centerVertical: false
                        width: parent.width
                        visible: text.length > 0
                        text: root.entry.summary
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: root.popup ? 4 : 2147483647
                        elide: Text.ElideRight
                        font.family: root.popup ? Theme.notificationFont : Theme.fontFamily
                    }
                }
                NotificationButton {
                    id: dismissButton
                    objectName: "notificationDismiss"
                    anchors.right: parent.right
                    width: Theme.controlHeight
                    height: width
                    glyph: Theme.cancelIcon
                    foreground: hovered || down ? Theme.text : Theme.accent
                    hint: root.popup ? "Dismiss popup; keep history" : "Delete this history entry"
                    background: Rectangle {
                        radius: width / 2
                        antialiasing: true
                        color: dismissButton.down ? Qt.darker(Theme.notificationCritical, 1.2) : dismissButton.hovered ? Theme.notificationCritical : Theme.alternateBackground
                        border.width: dismissButton.activeFocus ? 1 : 0
                        border.color: Theme.accent
                    }
                    onClicked: NotificationService.dismiss(root.entry, !root.popup)
                }
            }
            NotificationBody {
                objectName: "notificationBody"
                width: parent.width
                body: root.entry.body || ""
                popup: root.popup
            }
            Flow {
                id: actionFlow
                width: parent.width
                layoutDirection: Qt.RightToLeft
                spacing: Theme.controlSpacing
                visible: root.displayActions.length > 0
                Repeater {
                    model: root.displayActions
                    Item {
                        required property var modelData
                        id: actionItem
                        width: Math.min(actionButton.implicitWidth, actionFlow.width)
                        height: actionButton.implicitHeight
                        NotificationButton {
                            id: actionButton
                            objectName: "notificationAction_" + actionItem.modelData.identifier
                            anchors.fill: parent
                            clip: true
                            label: actionItem.modelData.text
                            enabled: actionItem.modelData.available
                            hint: actionItem.modelData.text
                            onClicked: NotificationService.invoke(root.entry, actionItem.modelData.identifier)
                        }
                        // Consume clicks on disabled actions instead of activating the card beneath.
                        MouseArea {
                            id: unavailableArea
                            anchors.fill: parent
                            visible: !actionItem.modelData.available
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.ArrowCursor
                        }
                        QC.ToolTip {
                            visible: unavailableArea.containsMouse
                            text: "This app action is no longer available."
                            delay: 500
                            contentItem: UI.ColumnText { text: "This app action is no longer available."; color: Theme.accent }
                            background: Rectangle { color: Theme.tooltipBackground; border.color: Theme.accent; border.width: 1 }
                        }
                    }
                }
            }
        }
    }
}
