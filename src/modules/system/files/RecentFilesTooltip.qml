pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import QtQuick.Dialogs as Dialogs
import Quickshell
import "../../../config"
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Column {
    id: root
    property var fileService: RecentFilesService
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxPanelHeight: (monitor?.height ?? 1080) * Theme.recentFilesMaxHeightRatio
    readonly property bool folderTab: fileService.activeFolder.length > 0
    property alias folderPicker: picker
    width: Math.min(Theme.recentFilesTooltipWidth, (monitor?.width ?? Theme.recentFilesTooltipWidth + Theme.tooltipPaddingWidth * 2) - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.controlSpacing
    Component.onCompleted: { fileService.beginPanel(); syncTabs() }
    Component.onDestruction: fileService.endPanel()
    function syncTabs() {
        tabs.currentIndex = folderTab ? Math.max(0, fileService.folders.indexOf(fileService.activeFolder) + 1) : 0
    }
    function openFolderPicker() {
        // Keep the source panel alive while the pointer is inside the picker.
        if (TooltipService.visible && !TooltipService.pinned)
            TooltipService.togglePin(TooltipService.x, TooltipService.content, TooltipService.source,
                TooltipService.centered, TooltipService.screen)
        picker.open()
    }
    Connections {
        target: root.fileService
        function onActiveFolderChanged() { Qt.callLater(root.syncTabs) }
        function onFoldersChanged() { Qt.callLater(root.syncTabs) }
    }
    Dialogs.FolderDialog {
        id: picker
        title: "Add folder tab"
        options: Dialogs.FolderDialog.ReadOnly
        onAccepted: root.fileService.addFolder(decodeURIComponent(selectedFolder.toString().replace(/^file:\/\/(?:localhost)?/, "")))
    }

    Item {
        id: header
        width: parent.width
        height: Theme.controlHeight
        UI.TabBar {
            id: tabs
            objectName: "recentFilesTabs"
            anchors.left: parent.left
            anchors.right: actions.left
            anchors.rightMargin: Theme.controlSpacing
            height: parent.height
            labels: ["Recent"].concat(root.fileService.folders.map(path => path.split("/").filter(part => part.length > 0).pop() || "/"))
            closeableTabs: [false].concat(root.fileService.folders.map(() => true))
            enabled: !root.fileService.dragging
            onTabClicked: index => root.fileService.selectFolder(index === 0 ? "" : root.fileService.folders[index - 1])
            onTabCloseRequested: index => root.fileService.removeFolder(root.fileService.folders[index - 1])
            onLabelsChanged: Qt.callLater(root.syncTabs)
        }
        Row {
            id: actions
            anchors.right: parent.right
            spacing: Theme.controlSpacing
            UI.ActionButton {
                glyph: Theme.refreshIcon
                hint: "Refresh files"
                enabled: !root.fileService.loading && !root.fileService.dragging
                onClicked: root.fileService.refresh()
            }
            UI.ActionButton {
                objectName: "addFolderTab"
                glyph: Theme.addIcon
                hint: "Add folder tab"
                enabled: !root.fileService.loading && !root.fileService.dragging
                onClicked: root.openFolderPicker()
            }
        }
    }
    UI.ColumnText {
        id: limits
        width: parent.width
        color: Theme.inactive
        text: root.folderTab ? root.fileService.activeFolder + " · max 20 files" : [Config.recentFilesMaxDays > 0 ? "Last " + Config.recentFilesMaxDays + " days" : "All time",
            Config.recentFilesMaxItems > 0 ? "max " + Config.recentFilesMaxItems + " files" : "all files"].join(" · ")
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
    }
    UI.ColumnText {
        id: feedback
        width: parent.width
        visible: root.fileService.error.length > 0 || root.fileService.files.length === 0
        text: root.fileService.error || (root.fileService.loading ? "Loading files…"
            : root.folderTab ? "No files in this folder." : "No recent files yet.")
        color: root.fileService.error ? Theme.warning : Theme.inactive
        wrapMode: Text.Wrap
    }
    ListView {
        id: list
        objectName: "recentFilesList"
        width: parent.width
        height: Math.min(contentHeight, Math.max(0, root.maxPanelHeight - header.height - limits.height
            - (feedback.visible ? feedback.height + root.spacing : 0)
            - (hint.visible ? hint.height + root.spacing : 0) - root.spacing * 2))
        model: root.fileService.files
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.fileService.dragging
        delegate: RecentFileRow {
            required property var modelData
            file: modelData
            fileService: root.fileService
            width: list.width - (scrollbar.visible ? Theme.scrollbarWidth + Theme.controlSpacing : 0)
        }
        QC.ScrollBar.vertical: UI.ScrollBar { id: scrollbar }
    }
    UI.ColumnText {
        id: hint
        width: parent.width
        visible: root.fileService.files.length > 0
        text: "Drag a file into an app, or click to open it."
        color: Theme.inactive
        font.pixelSize: 10
    }
}
