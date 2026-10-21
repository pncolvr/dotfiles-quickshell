pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../ui" as UI
import "../../theme"
import "../../services"

Row {
    id: root
    height: parent.height
    property real maximumWidth: parent.width
    readonly property real maximumTitleWidth: Math.max(0, maximumWidth
        - (windowTabs.visible ? windowTabs.width : 0))
    clip: true
    readonly property var titleWindows: WindowService.windows.filter(window =>
        window.active && !WindowService.groupedWindows.includes(window))
    HoverHandler {
        onHoveredChanged: {
            // console.warn("hovered:", hovered)
            if (hovered) WindowService.enableNoWarps()
            else WindowService.restoreNoWarps()
        }
    }

    UI.TabBar {
        actionTabs: true
        showSeparators: true
        id: windowTabs
        visible: WindowService.groupedWindows.length > 0
        labels: WindowService.groupedWindows.map(window => window.title.toLowerCase())
        width: Math.min(implicitWidth, Math.max(0, root.maximumWidth / 2))
        implicitHeight: root.height
        height: root.height
        tabPadding: Theme.groupedModuleSpacing / 2
        function syncFocusedWindow() {
            const focusedIndex = WindowService.groupedWindows.findIndex(window => window.active)
            setCurrentIndex(focusedIndex)
            for (let index = 0; index < count; index++) {
                const tab = itemAt(index) as QC.TabButton
                tab.checked = index === focusedIndex
            }
        }
        onLabelsChanged: Qt.callLater(windowTabs.syncFocusedWindow)
        onCountChanged: Qt.callLater(windowTabs.syncFocusedWindow)
        Connections {
            target: WindowService
            function onGroupedWindowsChanged() { Qt.callLater(windowTabs.syncFocusedWindow) }
        }
        onTabClicked: index => WindowService.focusWindow(WindowService.groupedWindows[index].address)
    }

    Repeater {
        model: root.titleWindows
        delegate: Item {
            required property var modelData

            implicitWidth: tabText.implicitWidth + Theme.moduleSpacing
            width: Math.min(implicitWidth, root.maximumTitleWidth)
            height: parent.height

            UI.Text {
                id: tabText
                objectName: "activeWindowTitle"
                anchors.left: parent.left
                anchors.leftMargin: Math.min(Theme.moduleSpacing / 2, parent.width / 2)
                anchors.right: parent.right
                anchors.rightMargin: anchors.leftMargin
                elide: Text.ElideRight
                textFormat: Text.PlainText
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
