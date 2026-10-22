pragma ComponentBehavior: Bound

import "../../../i18n"
import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../../config"
import "../../../theme"
import "../../../ui" as UI
import "../../../services"

Column {
    id: root
    property var fileService: RecentFilesService
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxPanelHeight: (monitor?.height ?? 1080) * Theme.recentFilesMaxHeightRatio
    readonly property bool folderTab: fileService.activeFolder.length > 0
    readonly property bool pinnedTab: fileService.showingPinned
    readonly property var tabEntries: [{label: Translations.text("files.tabs.recent"), kind: "recent", path: ""}]
        .concat(fileService.pinnedFiles.length > 0 ? [{label: Translations.text("files.tabs.pinned"), kind: "pinned", path: ""}] : [])
        .concat(fileService.folders.map(path => ({label: fileService.folderLabel(path), kind: "folder", path: path})))
    property var selectedUris: []
    property string selectionAnchor: ""
    property string renameFolder: ""
    readonly property var selectedFiles: fileService.files.filter(file => selectedUris.includes(file.uri))
    readonly property bool nativeDialogOpen: picker.nativeDialogOpen
    readonly property bool interactionPending: fileService.addingFolder === true
    property alias folderPicker: picker
    property alias dragSource: fileDragSource
    property int pinDropIndex: -1
    property real pinDropPointerY: 0
    property real dragPanelHeight: 0
    readonly property string pinDropBeforeUri: fileService.files[pinDropIndex]?.uri || ""
    height: fileDragSource.dragging ? dragPanelHeight : implicitHeight
    width: Math.min(Theme.recentFilesTooltipWidth, (monitor?.width ?? Theme.recentFilesTooltipWidth + Theme.tooltipPaddingWidth * 2) - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.controlSpacing
    Component.onCompleted: { fileService.beginPanel(); syncTabs() }
    Component.onDestruction: fileService.endPanel()
    function syncTabs() {
        tabs.currentIndex = Math.max(0, tabEntries.findIndex(tab => {
            switch (true) {
            case pinnedTab: return tab.kind === "pinned"
            case folderTab: return tab.kind === "folder" && tab.path === fileService.activeFolder
            default: return tab.kind === "recent"
            }
        }))
    }
    function clearSelection() { selectedUris = []; selectionAnchor = "" }
    function acceptPinDrag(drag) {
        drag.accepted = drag.hasUrls && (drag.supportedActions & Qt.CopyAction) !== 0
            && fileService.acceptsPinUrls(drag.urls)
    }
    function hoverPinned(drag) {
        pinnedHover.stop()
        acceptPinDrag(drag)
        if (drag.accepted && !pinnedTab) pinnedHover.restart()
    }
    function pinDrop(drop, beforeUri = "") {
        pinnedHover.stop()
        drop.accepted = false
        if (!drop.hasUrls || (drop.supportedActions & Qt.CopyAction) === 0 || !fileService.acceptsPinUrls(drop.urls)) return
        const accepted = fileDragSource.dragging && fileDragSource.originTab === "pinned"
            ? fileService.reorderPins(fileDragSource.files.map(file => file.uri), beforeUri)
            : fileService.pinUrls(drop.urls, beforeUri)
        if (accepted) drop.accept(Qt.CopyAction)
    }
    function updatePinDropPosition(y) {
        pinDropPointerY = y
        const index = list.indexAt(1, y + list.contentY)
        const row = list.itemAtIndex(index)
        switch (true) {
        case !!row:
            pinDropIndex = index + (y + list.contentY >= row.y + row.height / 2 ? 1 : 0)
            break
        case y + list.contentY <= 0:
            pinDropIndex = 0
            break
        default:
            pinDropIndex = list.count
        }
    }
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
        list.currentIndex = index
        const toggle = (modifiers & Qt.ControlModifier) !== 0
        const anchor = available.indexOf(selectionAnchor)
        switch (true) {
        case (modifiers & Qt.ShiftModifier) !== 0 && anchor >= 0: {
            const range = available.slice(Math.min(anchor, index), Math.max(anchor, index) + 1)
            selectedUris = toggle ? Array.from(new Set(selectedUris.concat(range))) : range
            return
        }
        case !toggle:
            selectedUris = [uri]
            break
        case selectedUris.includes(uri):
            selectedUris = selectedUris.filter(selected => selected !== uri)
            break
        default:
            selectedUris = selectedUris.concat([uri])
        }
        selectionAnchor = uri
    }
    function prepareDrag(uri, modifiers) {
        // Pressing a selected row must preserve the group until dragging begins.
        if (!selectedUris.includes(uri)) selectFile(uri, modifiers)
    }
    function dragFilesFor(uri) {
        return selectedUris.includes(uri) ? selectedFiles : fileService.files.filter(file => file.uri === uri)
    }
    function startFileDrag(uri, modifiers) {
        prepareDrag(uri, modifiers)
        dragPanelHeight = root.height
        fileDragSource.start(dragFilesFor(uri), fileService.activeTab)
    }
    FileDragSource { id: fileDragSource; fileService: root.fileService }
    Timer {
        id: pinnedHover
        interval: 350
        onTriggered: root.fileService.selectPinnedForDrag()
    }
    function focusSearch() {
        if (renameFolder) { aliasInput.forceActiveFocus(); aliasInput.selectAll() }
        else list.forceActiveFocus()
    }
    function editFolderName(path) {
        renameFolder = path
        aliasInput.text = fileService.folderLabel(path)
        Qt.callLater(() => {
            if (renameFolder === path) root.focusSearch()
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
    function openFolderPicker() { picker.open() }
    Connections {
        target: root.fileService
        function onActiveFolderChanged() { root.clearSelection(); root.cancelFolderName(); Qt.callLater(root.syncTabs) }
        function onShowingPinnedChanged() { root.clearSelection(); root.cancelFolderName(); list.positionViewAtBeginning(); Qt.callLater(root.syncTabs) }
        function onCurrentFolderChanged() { root.clearSelection(); root.cancelFolderName(); list.positionViewAtBeginning() }
        function onFoldersChanged() {
            if (!root.fileService.folders.includes(root.renameFolder)) root.renameFolder = ""
            Qt.callLater(root.syncTabs)
        }
        function onFilesChanged() { root.reconcileSelection() }
        function onFolderAdded(path) { root.editFolderName(path) }
    }
    UI.FolderDialog {
        id: picker
        title: Translations.text("files.actions.addTabHint")
        onFolderSelected: path => root.fileService.addFolder(path)
    }

    Item {
        id: filesHeader
        width: parent.width
        height: Theme.controlHeight
        UI.TabBar {
            id: tabs
            objectName: "recentFilesTabs"
            anchors.left: parent.left
            anchors.right: actions.left
            anchors.rightMargin: Theme.controlSpacing
            height: parent.height
            labels: root.tabEntries.map(tab => tab.label)
            interactionEnabled: !root.fileService.dragging
            dropEnabledTabs: root.tabEntries.map(tab => tab.kind === "pinned")
            onTabDragEntered: (index, drag) => root.hoverPinned(drag)
            onTabDragExited: index => pinnedHover.stop()
            onTabDropped: (index, drop) => root.pinDrop(drop)
            onTabClicked: index => {
                const tab = root.tabEntries[index]
                if (tab.kind === "pinned") root.fileService.selectPinned()
                else root.fileService.selectFolder(tab.path)
            }
            onLabelsChanged: Qt.callLater(root.syncTabs)
        }
        Row {
            id: actions
            anchors.right: parent.right
            spacing: Theme.controlSpacing
            UI.ActionButton {
                objectName: "refreshFiles"
                keyAction: "refresh"
                glyph: Theme.refreshIcon
                hint: Translations.text("files.actions.refreshHint")
                enabled: !root.fileService.loading && !root.fileService.dragging
                onClicked: root.fileService.refresh()
            }
            UI.ActionButton {
                objectName: "addFolderTab"
                keyAction: "add"
                glyph: Theme.addIcon
                hint: Translations.text("files.actions.addTabHint")
                enabled: !root.fileService.loading && !root.fileService.dragging
                onClicked: root.openFolderPicker()
            }
        }
    }
    Item {
        id: limits
        width: parent.width
        height: Theme.controlHeight
        UI.ColumnText {
            id: limitsLabel
            anchors.left: parent.left
            anchors.right: tabActions.left
            anchors.rightMargin: Theme.controlSpacing
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.inactive
            text: {
                switch (true) {
                case root.pinnedTab:
                    return Translations.text("files.summary.pinned",[root.fileService.pinnedFiles.length])
                case root.folderTab:
                    return root.fileService.currentFolder
                default: {
                    const period = Config.recentFilesMaxDays > 0 ? Translations.text("files.summary.days",[],Config.recentFilesMaxDays) : Translations.text("files.summary.allTime")
                    const limit = Config.recentFilesMaxItems > 0 ? Translations.text("files.summary.limit",[],Config.recentFilesMaxItems) : Translations.text("files.summary.allFiles")
                    return [period, limit].join(" · ")
                }
                }
            }
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            UI.HoverTooltip {
                objectName: "folderPathTooltip"
                enabled: root.folderTab
                text: root.fileService.currentFolder
            }
        }
        Row {
            id: tabActions
            anchors.right: parent.right
            enabled: !root.fileService.dragging
            spacing: Theme.controlSpacing
            UI.ActionButton {
                objectName: "navigateFolderUp"
                visible: root.folderTab
                glyph: Theme.upIcon
                hint: Translations.text("files.actions.goUp")
                enabled: root.fileService.canNavigateUp
                onClicked: root.fileService.navigateUp()
            }
            UI.ActionButton {
                objectName: "editFolderAlias"
                visible: root.folderTab
                glyph: Theme.editIcon
                hint: Translations.text("files.actions.renameTabHint")
                onClicked: {
                    if (root.renameFolder.length > 0) root.cancelFolderName()
                    else root.editFolderName(root.fileService.activeFolder)
                }
            }
            UI.ActionButton {
                objectName: "setDefaultTab"
                readonly property bool isDefault: root.fileService.defaultTab === root.fileService.activeTab
                    && (!root.folderTab || root.fileService.defaultFolder === root.fileService.activeFolder)
                glyph: Theme.defaultIcon
                foreground: isDefault ? Theme.accent : Theme.text
                hint: {
                    switch (true) {
                    case !isDefault: return Translations.text("files.actions.setDefaultHint")
                    case root.fileService.activeTab === "recent": return Translations.text("files.tabs.default")
                    default: return Translations.text("files.actions.defaultRecentHint")
                    }
                }
                onClicked: root.fileService.setDefaultTab(isDefault ? "recent" : root.fileService.activeTab,
                    root.fileService.activeFolder)
            }
            UI.ActionButton {
                objectName: "removeFolderTab"
                visible: root.folderTab
                glyph: Theme.deleteIcon
                hint: Translations.text("files.actions.removeTabHint")
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
            text: Translations.text("files.tab.nameLabel",[root.renameFolder])
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
                placeholderText: Translations.text("files.tab.namePlaceholder")
                Accessible.name: Translations.text("files.tab.nameAccessibleName")
                onAccepted: root.saveFolderName()
                Keys.onPressed: event => UI.Keybinds.handleCancel(event, () => root.cancelFolderName())
            }
            UI.EditorActions {
                id: renameActions
                anchors.right: parent.right
                cancelObjectName: "cancelFolderAlias"
                submitObjectName: "saveFolderAlias"
                submitHint: Translations.text("files.actions.applyNameHint")
                cancelHint: Translations.text("files.actions.cancelNameHint")
                onSubmitted: root.saveFolderName()
                onCancelled: root.cancelFolderName()
            }
        }
    }
    UI.ColumnText {
        id: feedback
        width: parent.width
        visible: root.fileService.error.length > 0 || root.fileService.files.length === 0
        text: {
            switch (true) {
            case root.fileService.error.length > 0: return root.fileService.error
            case root.fileService.loading: return Translations.text("files.status.loading")
            case root.folderTab: return Translations.text("files.empty.folder")
            default: return Translations.text("files.empty.recent")
            }
        }
        color: root.fileService.error ? Theme.warning : Theme.inactive
        wrapMode: Text.Wrap
    }
    ListView {
        id: list
        property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: list; enabled: !root.fileService.dragging }
        objectName: "recentFilesList"
        width: root.width + Theme.scrollbarGutter
        height: Math.min(contentHeight, Math.max(0, (fileDragSource.dragging ? root.dragPanelHeight : root.maxPanelHeight) - filesHeader.height - limits.height
            - (renameEditor.visible ? renameEditor.height + root.spacing : 0)
            - (feedback.visible ? feedback.height + root.spacing : 0)
            - (hint.visible ? hint.height + root.spacing : 0) - root.spacing * 2))
        model: root.fileService.files
        activeFocusOnTab: true
        keyNavigationEnabled: false
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: if (pinnedDrop.containsDrag) root.updatePinDropPosition(root.pinDropPointerY)
        Keys.onPressed: event => {
            if (root.fileService.dragging) return
            if (UI.Keybinds.matches(event, "cancel")) {
                if (root.selectedUris.length) UI.Keybinds.handleCancel(event, () => root.clearSelection())
                return
            }
            if (UI.Keybinds.matches(event, "selection.all")) {
                root.selectedUris = root.fileService.files.map(file => file.uri)
                root.selectionAnchor = root.selectedUris[0] || ""
                event.accepted = true
                return
            }
            switch (event.key) {
            case Qt.Key_Up:
            case Qt.Key_Down:
                if (!count) return
                currentIndex = Math.max(0,Math.min(count - 1,currentIndex + (event.key === Qt.Key_Down ? 1 : -1)))
                positionViewAtIndex(currentIndex,ListView.Contain)
                root.selectFile(root.fileService.files[currentIndex].uri,event.modifiers)
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (!root.fileService.files[currentIndex]) return
                root.fileService.openFile(root.fileService.files[currentIndex])
                break
            case Qt.Key_Space:
                if (!root.fileService.files[currentIndex]) return
                root.selectFile(root.fileService.files[currentIndex].uri,event.modifiers)
                break
            default:
                return
            }
            event.accepted = true
        }
        delegate: RecentFileRow {
            required property int index
            keyboardCurrent: list.activeFocus && list.currentIndex === index
            required property var modelData
            file: modelData
            fileService: root.fileService
            selection: root
            width: root.width
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
        DropArea {
            id: pinnedDrop
            objectName: "pinnedFilesDrop"
            parent: list
            anchors.fill: parent
            enabled: root.pinnedTab
            onEntered: drag => {
                root.acceptPinDrag(drag)
                if (drag.accepted) root.updatePinDropPosition(drag.y)
            }
            onPositionChanged: drag => root.updatePinDropPosition(drag.y)
            onDropped: drop => {
                root.updatePinDropPosition(drop.y)
                root.pinDrop(drop, root.pinDropBeforeUri)
            }
            Rectangle {
                anchors.fill: parent
                visible: pinnedDrop.containsDrag
                color: "transparent"
                border.width: 1
                border.color: Theme.accent
                radius: Theme.iconButtonRadius
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                visible: pinnedDrop.containsDrag && root.pinDropIndex >= 0
                height: 2
                color: Theme.accent
                y: Math.max(0, Math.min(pinnedDrop.height - height,
                    (root.pinDropIndex === list.count ? list.contentHeight
                        : list.itemAtIndex(root.pinDropIndex)?.y ?? 0) - list.contentY))
            }
            Timer {
                interval: 50
                repeat: true
                running: pinnedDrop.containsDrag
                onTriggered: {
                    const edge = Theme.recentFilesRowHeight / 2
                    const direction = root.pinDropPointerY < edge ? -1
                        : root.pinDropPointerY > list.height - edge ? 1 : 0
                    if (direction) list.contentY = Math.max(list.originY,
                        Math.min(list.originY + Math.max(0, list.contentHeight - list.height), list.contentY + direction * 12))
                }
            }
        }
    }
    UI.ShortcutHints {
        id: hint
        width: parent.width
        visible: root.fileService.files.length > 0 && text.length > 0
        panelKey: "files"
        availableActions: ["files.multiple", "selection.all"].concat(root.selectedUris.length ? ["files.drag"] : [])
        actionOverrides: ({
            "files.multiple": {sequence: "Ctrl/Shift"},
            "files.drag": {sequence: Translations.text("hints.drag")},
            "selection.all": {label: Translations.text("hints.selectAll")}
        })
        color: Theme.inactive
        font.pixelSize: 10
        horizontalAlignment: Text.AlignHCenter
    }
}
