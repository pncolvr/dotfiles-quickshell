pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../"
import "../" as UI

QC.TabBar {
    id: root
    property var labels: []
    property var closeableTabs: []
    property real tabPadding: Theme.controlFieldPadding * 2
    property real closeButtonWidth: 16
    property real underlineBottomMargin: 3
    signal tabClicked(int index)
    signal tabCloseRequested(int index)
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
            contentItem: Item {
                UI.Text {
                    id: tabLabel
                    centerVertical: false
                    anchors.fill: parent
                    anchors.rightMargin: closeButton.visible ? root.closeButtonWidth + Theme.controlSpacing : 0
                    text: tabButton.text
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
                    glyph: Theme.cancelIcon
                    foreground: hovered ? Theme.text : Theme.inactive
                    fillColor: "transparent"
                    hint: "Remove " + tabButton.text + " tab"
                    onClicked: root.tabCloseRequested(tabButton.index)
                }
            }
            background: Rectangle {
                color: tabButton.down ? Qt.darker(Theme.alternateBackground, 1.2)
                    : tabButton.hovered ? Theme.alternateBackground : "transparent"
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
            onClicked: root.tabClicked(index)
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
}
