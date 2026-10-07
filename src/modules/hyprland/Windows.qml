pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
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

    UI.TabBar {
        id: windowTabs
        visible: WindowService.isSpecialWorkspace
        labels: WindowService.isSpecialWorkspace
            ? WindowService.windows.map(window => window.title.toLowerCase()) : []
        width: implicitWidth
        implicitHeight: root.height
        height: root.height
        tabPadding: Theme.groupedModuleSpacing / 2
        function syncFocusedWindow() {
            const focusedIndex = visible ? WindowService.windows.findIndex(window => window.active) : -1
            setCurrentIndex(focusedIndex)
            for (let index = 0; index < count; index++) {
                const tab = itemAt(index) as QC.TabButton
                tab.checked = index === focusedIndex
            }
        }
        onLabelsChanged: Qt.callLater(windowTabs.syncFocusedWindow)
        onCountChanged: Qt.callLater(windowTabs.syncFocusedWindow)
        onTabClicked: index => WindowService.focusWindow(WindowService.windows[index].address)
    }

    Repeater {
        model: WindowService.isSpecialWorkspace ? [] : WindowService.windows
        delegate: Item {
            required property var modelData

            implicitWidth: tabText.implicitWidth + Theme.moduleSpacing
            height: parent.height

            UI.Text {
                id: tabText
                anchors.left: parent.left
                anchors.leftMargin: Theme.moduleSpacing / 2
                text: parent.modelData.title.toLowerCase()
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
