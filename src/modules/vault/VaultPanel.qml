pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"
import "../../services/launcher/Search.mjs" as Search
Item {
    id: root
    property bool editing: false
    property bool adding: false
    property bool deleting: false
    property string query: ""
    property string folderFilter: ""
    property string typeFilter: "Login"
    property string notice: ""
    readonly property string selectedEntryId: root.rows[list.currentIndex]?.id ?? ""
    onSelectedEntryIdChanged: Qt.callLater(root.updateSelection)
    onNoticeChanged: { if (notice) noticeExpiry.restart(); else noticeExpiry.stop() }
    Timer { id: noticeExpiry; interval: 5000; onTriggered: root.notice = "" }
    property bool detailBusyShown: false
    readonly property bool detailReady: !!RbwService.detail && RbwService.detail.id === root.selectedEntryId
    Timer { id: detailBusyDelay; interval: 200; onTriggered: root.detailBusyShown = true }
    readonly property var rows: {
        const searchText = query.trim()
        const pattern = Search.searchPattern(searchText, Config.pickerSmartCase)
        return RbwService.entries.filter(row => (!folderFilter || (row.folder ?? "") === folderFilter)
            && (!typeFilter || row.type === typeFilter)).map(row => ({row, score: Search.score([row.name, row.user, row.folder, ...(row.uris ?? [])].filter(Boolean).join(" "), pattern, Config.pickerFuzzySearch)}))
            .filter(item => item.score !== Infinity).sort((a, b) => a.score - b.score || a.row.name.localeCompare(b.row.name)).map(item => item.row)
    }
    readonly property bool editable: !!RbwService.detail?.data?.hasOwnProperty("password")
    readonly property var detailRows: {
        const entry = RbwService.detail
        if (!entry) return []
        const fields = (entry.data?.uris ?? []).map(uri => ({label: "Website", value: uri.uri, secret: false}))
        fields.push(...Object.entries(entry.data ?? {}).filter(([key, value]) => value !== null && key !== "uris"
                && (key !== "totp" || (typeof value === "string" && value.length > 0)))
            .map(([key, value]) => ({label: key === "totp" ? "TOTP secret" : key.replace(/_/g, " "),
                value: String(value), secret: key !== "username", totp: key === "totp"})))
        if (entry.notes) fields.push({label: "Notes", value: entry.notes, secret: true, multiline: true})
        for (const field of entry.fields ?? []) if (field.value != null) fields.push({label: field.name || "Custom field", value: field.value, secret: true})
        return fields
    }
    function focusSearch() { if (!editing) search.forceActiveFocus() }
    function updateSelection() {
        if (!root.editing && !root.deleting) RbwService.select(root.selectedEntryId)
    }
    function selectFirst() {
        list.currentIndex = root.rows.length ? 0 : -1
        root.updateSelection()
    }
    function discard() { editing = false; adding = false; deleting = false; editor.clear() }
    function newLogin() {
        if (RbwService.busy || editing) return
        RbwService.clear(); discard(); editing = true; adding = true
        Qt.callLater(editor.focusNew)
    }
    function edit() {
        if (!editable || RbwService.busy) return
        discard(); editing = true
        editor.loadEntry(RbwService.detail)
    }
    function save() {
        RbwService.save(editor.draft(adding ? "" : RbwService.detail?.id))
    }
    function copy(value) {
        if (!value) return
        RbwService.copy(value)
    }
    function back() { if (editing || deleting) { discard(); focusSearch() } else RbwService.close() }
    Component.onDestruction: discard()
    Connections {
        target: RbwService
        function onEntriesChanged() {
            root.selectFirst()
        }
        function onCleared() { root.discard() }
        function onSaved() { root.discard(); root.notice = "Saved." }
        function onGenerated(value) { if (root.editing) editor.setPassword(value) }
        function onCopied() { root.notice = "Copied; clipboard expires after 30 seconds." }
        function onSelectingChanged() {
            root.detailBusyShown = false
            if (RbwService.selecting) detailBusyDelay.restart()
            else detailBusyDelay.stop()
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.back(); event.accepted = true }
    }
    Column {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.tooltipPaddingWidth
        spacing: Theme.controlSpacing
        Item {
            width: parent.width
            height: Theme.controlHeight
            UI.InputField {
                id: search
                objectName: "vaultSearch"
                anchors.left: parent.left
                anchors.right: headerActions.left
                anchors.rightMargin: Theme.controlSpacing
                pauseTooltipDismissal: false
                enabled: !root.editing && !root.deleting
                placeholderText: "Search names, usernames and websites…"
                onTextChanged: { root.query = text; root.selectFirst() }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) { list.currentIndex = Math.min(root.rows.length - 1, list.currentIndex + 1); event.accepted = true }
                    if (event.key === Qt.Key_Up) { list.currentIndex = Math.max(0, list.currentIndex - 1); event.accepted = true }
                }
                onAccepted: if (root.rows[list.currentIndex]) RbwService.select(root.rows[list.currentIndex].id)
            }
            Row {
                id: headerActions
                anchors.right: parent.right
                spacing: Theme.controlSpacing
                UI.ActionButton { glyph: Theme.refreshIcon; hint: "Sync / unlock vault"; enabled: !RbwService.busy && !root.editing; onClicked: RbwService.reload(true) }
                UI.ActionButton { objectName: "vaultLock"; glyph: Theme.lockIcon; hint: "Lock vault"; enabled: !RbwService.busy; onClicked: RbwService.lock() }
                UI.ActionButton { objectName: "vaultAdd"; glyph: Theme.addIcon; hint: "New login"; enabled: !RbwService.busy && !root.editing && !root.deleting; onClicked: root.newLogin() }
            }
        }
        Row {
            objectName: "vaultFilters"
            width: parent.width
            spacing: Theme.controlSpacing
            UI.ComboSelector {
                toggleObjectName: "vaultFolderToggle"
                choicesObjectName: "vaultFolderChoices"
                labelPrefix: "Folder: "
                hint: "Filter by folder"
                width: (parent.width - Theme.controlSpacing) / 2
                compact: true
                enabled: !root.editing && !root.deleting && (!RbwService.busy || RbwService.selecting)
                options: [{name: "", description: "All folders"}, ...RbwService.folders.map(value => ({name: value, description: value}))]
                selectedName: root.folderFilter
                onSelected: name => { root.folderFilter = name; root.selectFirst() }
            }
            UI.ComboSelector {
                width: (parent.width - Theme.controlSpacing) / 2
                compact: true
                enabled: !root.editing && !root.deleting && (!RbwService.busy || RbwService.selecting)
                options: [{name: "Login", description: "Logins"}, ...[...new Set(RbwService.entries.map(row => row.type).filter(value => value && value !== "Login"))].sort().map(value => ({name: value, description: value === "Note" ? "Notes" : value}))]
                toggleObjectName: "vaultTypeToggle"
                choicesObjectName: "vaultTypeChoices"
                labelPrefix: "Type: "
                hint: "Filter by item type"
                selectedName: root.typeFilter
                onSelected: name => { root.typeFilter = name; root.selectFirst() }
            }
        }
        Row {
            width: parent.width
            height: Math.max(100, content.height - y - footer.height - Theme.controlSpacing)
            spacing: Theme.controlSpacing * 2
            VaultEntryList {
                id: list
                width: parent.width * 0.38
                height: parent.height
                entries: root.rows
                busy: RbwService.busy
                enabled: !root.editing && !root.deleting && (!RbwService.busy || RbwService.selecting)
                onEntrySelected: entryId => RbwService.select(entryId)
            }
            Item {
                id: detailsPane
                objectName: "vaultDetails"
                width: parent.width - list.width - parent.spacing
                height: parent.height
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    z: 1
                    color: "transparent"
                    radius: Theme.iconButtonRadius
                    border.width: 1
                    border.color: Theme.empty
                }
                Flickable {
                    id: details
                    objectName: "vaultDetailScroll"
                    width: parent.width
                    height: parent.height - Theme.controlHeight - Theme.controlSpacing * 2
                    contentWidth: width
                    contentHeight: detailContent.implicitHeight + Theme.controlSpacing * 2
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    QC.ScrollBar.vertical: UI.ScrollBar {}
                    Column {
                        id: detailContent
                        x: Theme.controlSpacing
                        y: Theme.controlSpacing
                        width: details.width - 10 - Theme.controlSpacing * 2
                        spacing: Theme.controlSpacing
                        UI.Text { centerVertical: false; width: parent.width; textFormat: Text.PlainText; wrapMode: Text.Wrap; text: root.adding ? "New login" : RbwService.detail?.name ?? "Click an entry to open details." }
                        UI.Text { centerVertical: false; width: parent.width; textFormat: Text.PlainText; wrapMode: Text.Wrap; visible: !!RbwService.detail; color: Theme.inactive; text: RbwService.detail?.folder ?? "No folder" }
                        VaultEntryDetails {
                            width: parent.width
                            visible: !root.editing && !root.deleting
                            enabled: root.detailReady && !RbwService.busy
                            fields: root.detailRows
                            onCopyRequested: value => root.copy(value)
                        }
                        Column {
                            width: parent.width
                            visible: root.deleting
                            spacing: Theme.controlSpacing
                            UI.Text { centerVertical: false; width: parent.width; textFormat: Text.PlainText; wrapMode: Text.Wrap; text: "Delete “" + (RbwService.detail?.name ?? "") + "”? This removes the vault entry."; color: Theme.warning }
                        }
                        VaultEntryEditor {
                            id: editor
                            width: parent.width
                            visible: root.editing
                            enabled: !RbwService.busy
                            adding: root.adding
                            onCopyRequested: value => root.copy(value)
                        }
                    }
                }
                Item {
                    id: detailActions
                    objectName: "vaultDetailActions"
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.controlSpacing
                    width: Theme.actionButtonWidth * 2 + Theme.controlSpacing
                    height: Theme.controlHeight
                    visible: root.rows.length > 0 || root.editing || root.deleting
                    Row {
                        anchors.right: parent.right
                        visible: !root.editing && !root.deleting
                        spacing: Theme.controlSpacing
                        UI.ActionButton { objectName: "vaultEdit"; glyph: Theme.editIcon; hint: "Edit password"; visible: root.editable; enabled: root.detailReady && root.editable && !RbwService.busy; onClicked: root.edit() }
                        UI.ActionButton { objectName: "vaultDelete"; glyph: Theme.deleteIcon; hint: "Delete entry"; fillColor: Theme.urgent; enabled: root.detailReady && !RbwService.busy; onClicked: root.deleting = true }
                    }
                    UI.EditorActions {
                        objectName: "vaultEditorActions"
                        anchors.right: parent.right
                        visible: root.editing
                        submitObjectName: "vaultSave"
                        cancelObjectName: "vaultCancel"
                        submitGlyph: root.adding ? Theme.addIcon : Theme.checkIcon
                        submitHint: root.adding ? "Create login" : "Save changes"
                        submitEnabled: !RbwService.busy && (!root.adding || editor.validTitle)
                        cancelEnabled: !RbwService.busy
                        onSubmitted: root.save()
                        onCancelled: { root.discard(); root.focusSearch() }
                    }
                    UI.EditorActions {
                        anchors.right: parent.right
                        visible: root.deleting
                        submitGlyph: Theme.deleteIcon
                        submitColor: Theme.urgent
                        submitHint: "Delete entry"
                        submitEnabled: !RbwService.busy
                        cancelEnabled: !RbwService.busy
                        onSubmitted: RbwService.remove()
                        onCancelled: root.deleting = false
                    }
                }
            }
        }
        Column {
            id: footer
            objectName: "vaultFooter"
            width: parent.width
            spacing: Theme.controlSpacing
            Item {
                id: footerFeedback
                width: parent.width
                height: Math.max(formHints.implicitHeight, status.visible ? status.implicitHeight : 0)
                UI.ShortcutHints {
                    id: formHints
                    objectName: "vaultFormHints"
                    width: parent.width
                    visible: !status.visible
                    hints: root.editing || root.deleting ? "Esc: cancel" : "Click / Enter: details · Esc: close"
                }
                UI.Text {
                    id: status
                    objectName: "vaultStatus"
                    anchors.right: parent.right
                    width: parent.width
                    centerVertical: false
                    font.pixelSize: Theme.fontSize - 1
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                    visible: text.length > 0
                    text: (RbwService.busy && !RbwService.selecting) || root.detailBusyShown ? "Working…" : RbwService.error || root.notice
                    color: RbwService.error ? Theme.warning : Theme.inactive
                }
            }
        }
    }
}
