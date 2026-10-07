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
    property var selectedUris: []
    property string selectionAnchor: ""
    property string renameFolder: ""
    readonly property var selectedFiles: fileService.files.filter(file => selectedUris.includes(file.uri))
    property alias folderPicker: picker
    width: Math.min(Theme.recentFilesTooltipWidth, (monitor?.width ?? Theme.recentFilesTooltipWidth + Theme.tooltipPaddingWidth * 2) - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.controlSpacing
    Component.onCompleted: { fileService.beginPanel(); syncTabs() }
    Component.onDestruction: fileService.endPanel()
    function syncTabs() {
        tabs.currentIndex = folderTab ? Math.max(0, fileService.folders.indexOf(fileService.activeFolder) + 1) : 0
    }
    function clearSelection() { selectedUris = []; selectionAnchor = "" }
    function reconcileSelection() {
        const available = fileService.files.map(file => file.uri)
        selectedUris = selectedUris.filter(uri => available.includes(uri))
        if (!available.includes(selectionAnchor)) selectionAnchor = ""
    }
    function selectFile(uri, modifiers) {
        if (fileService.dragging) return
        list.forceActiveFocus()
        const available = fileService.files.map(file => file.uri)
        const index = available.indexOf(uri)
        if (index < 0) return
        const toggle = (modifiers & Qt.ControlModifier) !== 0
        const anchor = available.indexOf(selectionAnchor)
        if ((modifiers & Qt.ShiftModifier) && anchor >= 0) {
            const range = available.slice(Math.min(anchor, index), Math.max(anchor, index) + 1)
            selectedUris = toggle ? Array.from(new Set(selectedUris.concat(range))) : range
        } else {
            selectedUris = toggle ? (selectedUris.includes(uri)
                ? selectedUris.filter(selected => selected !== uri) : selectedUris.concat([uri])) : [uri]
            selectionAnchor = uri
        }
    }
    function prepareDrag(uri, modifiers) {
        // Pressing a selected row must preserve the group until dragging begins.
        if (!selectedUris.includes(uri)) selectFile(uri, modifiers)
    }
    function editFolderName(path) {
        renameFolder = path
        aliasInput.text = fileService.folderLabel(path)
        Qt.callLater(() => {
            if (renameFolder === path) { aliasInput.forceActiveFocus(); aliasInput.selectAll() }
        })
    }
    function saveFolderName() {
        if (fileService.setFolderAlias(renameFolder, aliasInput.text)) cancelFolderName()
    }
    function cancelFolderName() {
        renameFolder = ""
        aliasInput.clear()
        list.forceActiveFocus()
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
        function onActiveFolderChanged() { root.clearSelection(); root.cancelFolderName(); Qt.callLater(root.syncTabs) }
        function onCurrentFolderChanged() { root.clearSelection(); root.cancelFolderName(); list.positionViewAtBeginning() }
        function onFoldersChanged() {
            if (!root.fileService.folders.includes(root.renameFolder)) root.renameFolder = ""
            Qt.callLater(root.syncTabs)
        }
        function onFilesChanged() { root.reconcileSelection() }
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
            labels: ["Recent"].concat(root.fileService.folders.map(path => root.fileService.folderLabel(path)))
            enabled: !root.fileService.dragging
            onTabClicked: index => root.fileService.selectFolder(index === 0 ? "" : root.fileService.folders[index - 1])
            onLabelsChanged: Qt.callLater(root.syncTabs)
        }
        Row {
            id: actions
            anchors.right: parent.right
            spacing: Theme.controlSpacing
            UI.ActionButton {
                objectName: "refreshFiles"
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
    Item {
        id: limits
        width: parent.width
        height: root.folderTab ? Theme.controlHeight : limitsLabel.implicitHeight
        UI.ColumnText {
            id: limitsLabel
            anchors.left: parent.left
            anchors.right: folderActions.left
            anchors.rightMargin: root.folderTab ? Theme.controlSpacing : 0
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.inactive
            text: root.folderTab ? root.fileService.currentFolder : [Config.recentFilesMaxDays > 0 ? "Last " + Config.recentFilesMaxDays + " days" : "All time",
                Config.recentFilesMaxItems > 0 ? "max " + Config.recentFilesMaxItems + " files" : "all files"].join(" · ")
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            UI.HoverTooltip {
                objectName: "folderPathTooltip"
                enabled: root.folderTab
                text: root.fileService.currentFolder
            }
        }
        Row {
            id: folderActions
            anchors.right: parent.right
            width: visible ? implicitWidth : 0
            visible: root.folderTab
            enabled: !root.fileService.dragging
            spacing: Theme.controlSpacing
            UI.ActionButton {
                objectName: "navigateFolderUp"
                glyph: Theme.upIcon
                hint: "Go up"
                enabled: root.fileService.canNavigateUp
                onClicked: root.fileService.navigateUp()
            }
            UI.ActionButton {
                objectName: "editFolderAlias"
                glyph: Theme.editIcon
                hint: "Edit tab name"
                onClicked: {
                    if (root.renameFolder.length > 0) root.cancelFolderName()
                    else root.editFolderName(root.fileService.activeFolder)
                }
            }
            UI.ActionButton {
                objectName: "setDefaultFolder"
                readonly property bool isDefault: root.fileService.defaultFolder === root.fileService.activeFolder
                glyph: Theme.defaultIcon
                foreground: isDefault ? Theme.accent : Theme.text
                hint: isDefault ? "Use Recent as default" : "Set as default tab"
                onClicked: root.fileService.setDefaultFolder(isDefault ? "" : root.fileService.activeFolder)
            }
            UI.ActionButton {
                objectName: "removeFolderTab"
                glyph: Theme.deleteIcon
                hint: "Remove folder tab"
                fillColor: Theme.urgent
                onClicked: root.fileService.removeFolder(root.fileService.activeFolder)
            }
        }
    }
    Column {
        id: renameEditor
        objectName: "folderAliasEditor"
        width: parent.width
        visible: root.renameFolder.length > 0
        spacing: Theme.controlSpacing
        UI.ColumnText {
            width: parent.width
            text: "Tab name · " + root.renameFolder
            textFormat: Text.PlainText
            color: Theme.inactive
            elide: Text.ElideMiddle
        }
        Item {
            width: parent.width
            height: Theme.controlHeight
            UI.InputField {
                id: aliasInput
                objectName: "folderAliasInput"
                anchors.left: parent.left
                anchors.right: renameActions.left
                anchors.rightMargin: Theme.controlSpacing
                placeholderText: "Blank uses the folder name"
                Accessible.name: "Folder tab name"
                onAccepted: root.saveFolderName()
                Keys.onEscapePressed: root.cancelFolderName()
            }
            UI.EditorActions {
                id: renameActions
                anchors.right: parent.right
                cancelObjectName: "cancelFolderAlias"
                submitObjectName: "saveFolderAlias"
                submitHint: "Apply tab name"
                cancelHint: "Cancel rename"
                onSubmitted: root.saveFolderName()
                onCancelled: root.cancelFolderName()
            }
        }
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
            - (renameEditor.visible ? renameEditor.height + root.spacing : 0)
            - (feedback.visible ? feedback.height + root.spacing : 0)
            - (hint.visible ? hint.height + root.spacing : 0) - root.spacing * 2))
        model: root.fileService.files
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.fileService.dragging
        Keys.onPressed: event => {
            if (root.fileService.dragging) return
            if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                root.selectedUris = root.fileService.files.map(file => file.uri)
                root.selectionAnchor = root.selectedUris[0] || ""
                event.accepted = true
            } else if (event.key === Qt.Key_Escape && root.selectedUris.length > 0) {
                root.clearSelection()
                event.accepted = true
            }
        }
        delegate: RecentFileRow {
            required property var modelData
            file: modelData
            fileService: root.fileService
            selection: root
            width: list.width - (scrollbar.visible ? Theme.scrollbarWidth + Theme.controlSpacing : 0)
        }
        QC.ScrollBar.vertical: UI.ScrollBar { id: scrollbar }
    }
    UI.ColumnText {
        id: hint
        width: parent.width
        visible: root.fileService.files.length > 0
        text: (root.selectedUris.length > 0 ? root.selectedUris.length + " selected · Drag into an app.\n" : "")
            + "Click to select · Ctrl/Shift for multiple · Double-click to open"
        color: Theme.inactive
        font.pixelSize: 10
        wrapMode: Text.Wrap
    }
}
