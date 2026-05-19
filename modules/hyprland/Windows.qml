pragma ComponentBehavior: Bound

import QtQuick
import "../../theme/ui" as UI
import "../../theme"
import "../../services"

Row {
    id: root
    spacing: 0
    height: parent.height
    HoverHandler {
        onHoveredChanged: {
            // console.warn("hovered:", hovered)
            if (hovered) WindowService.enableNoWarps()
            else WindowService.restoreNoWarps()
        }
    }
    Repeater {
        model: WindowService.windows
        delegate: Item {
            
            required property var modelData
            required property int index

            implicitWidth: tabText.implicitWidth + (WindowService.isSpecialWorkspace ? 16 : Theme.moduleSpacing)
            height: parent.height

            Rectangle {
                visible: WindowService.isSpecialWorkspace
                anchors.bottom: parent.bottom
                width: parent.width
                height: 2
                color: parent.modelData.active ? Theme.accent : "transparent"
            }

            UI.Text {
                id: tabText
                anchors.centerIn: parent
                text: parent.modelData.title
                color: parent.modelData.active ? Theme.accent : Theme.inactive
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: WindowService.focusWindow(parent.modelData.address)
            }
        }
    }

    // UI.IconText {
    //     visible: WindowService.activeWindowHidden
    //     text: ""
    //     color: WindowService.activeWindowHidden ? Theme.accent : Theme.inactive
    // }
}