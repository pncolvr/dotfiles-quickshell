pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../"
import "../" as UI

QC.TabBar {
    id: root
    property var labels: []
    property var closeableTabs: []
    property var dropEnabledTabs: []
    property bool interactionEnabled: true
    property real tabPadding: Theme.controlFieldPadding * 2
    property real closeButtonWidth: 16
    property real underlineBottomMargin: 3
    signal tabClicked(int index)
    signal tabCloseRequested(int index)
    signal tabDragEntered(int index, DragEvent drag)
    signal tabDragExited(int index)
    signal tabDropped(int index, DragEvent drop)
    implicitHeight: Theme.controlHeight
    clip: true
    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const view = root.contentItem as ListView
            if (!view || view.contentWidth <= view.width) { event.accepted = false; return }
            const delta = event.pixelDelta.x || event.pixelDelta.y
                || (event.angleDelta.x || event.angleDelta.y) / 120 * 40
            view.cancelFlick()
            view.contentX = Math.max(view.originX,
                Math.min(view.originX + view.contentWidth - view.width, view.contentX - delta))
            event.accepted = true
        }
    }
    background: Rectangle {
        color: "transparent"
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.underlineBottomMargin
            width: parent.width
            height: 1
            color: Theme.empty
        }
    }
    Repeater {
        model: root.labels
        QC.TabButton {
            id: tabButton
            required property string modelData
            required property int index
            text: modelData
            width: implicitWidth
            implicitWidth: tabLabel.implicitWidth + root.tabPadding * 2
                + (closeButton.visible ? root.closeButtonWidth + Theme.controlSpacing : 0)
            implicitHeight: root.implicitHeight
            padding: 0
            hoverEnabled: true
            focusPolicy: root.interactionEnabled ? Qt.StrongFocus : Qt.NoFocus
            contentItem: Item {
                UI.Text {
                    id: tabLabel
                    centerVertical: false
                    anchors.fill: parent
                    anchors.rightMargin: (closeButton.visible ? root.closeButtonWidth + Theme.controlSpacing : 0)
                    text: tabButton.text
                    textFormat: Text.PlainText
                    color: tabButton.checked ? Theme.accent : Theme.inactive
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                UI.ActionButton {
                    id: closeButton
                    objectName: "tabCloseButton"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: root.tabPadding / 2
                    width: root.closeButtonWidth
                    height: parent.height - root.underlineBottomMargin - 4
                    visible: root.closeableTabs[tabButton.index] === true
                    enabled: root.interactionEnabled
                    glyph: Theme.cancelIcon
                    foreground: hovered ? Theme.text : Theme.inactive
                    fillColor: "transparent"
                    hint: "Remove " + tabButton.text + " tab"
                    onClicked: root.tabCloseRequested(tabButton.index)
                }
            }
            background: Rectangle {
                color: tabButton.down ? Qt.darker(Theme.alternateBackground, 1.2)
                    : tabButton.hovered || tabDrop.containsDrag ? Theme.alternateBackground : "transparent"
                border.width: tabDrop.containsDrag ? 1 : 0
                border.color: Theme.accent
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.underlineBottomMargin
                    x: tabButton.contentItem.x + tabLabel.x + (tabLabel.width - width) / 2
                    width: tabLabel.implicitWidth
                    height: 2
                    visible: tabButton.checked
                    color: Theme.accent
                }
            }
            onClicked: { if (root.interactionEnabled) root.tabClicked(index) }
            // Block activation during source drags while keeping drop targets alive.
            MouseArea { anchors.fill: parent; visible: !root.interactionEnabled }
            DropArea {
                id: tabDrop
                anchors.fill: parent
                enabled: root.dropEnabledTabs[tabButton.index] === true
                onEntered: drag => { drag.accepted = false; root.tabDragEntered(tabButton.index, drag) }
                onExited: root.tabDragExited(tabButton.index)
                onDropped: drop => { drop.accepted = false; root.tabDropped(tabButton.index, drop) }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
}
