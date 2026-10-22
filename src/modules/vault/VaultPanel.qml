pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../ui" as UI
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
    property string typeFilter: Translations.text("vault.types.login")
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
        const fields = (entry.data?.uris ?? []).map(uri => ({label: Translations.text("vault.fields.website"), value: uri.uri, secret: false}))
        fields.push(...Object.entries(entry.data ?? {}).filter(([key, value]) => value !== null && key !== "uris"
                && (key !== "totp" || (typeof value === "string" && value.length > 0)))
            .map(([key, value]) => ({label: key === "totp" ? Translations.text("vault.fields.totp") : key.replace(/_/g, " "),
                value: String(value), secret: key !== "username", totp: key === "totp"})))
        if (entry.notes) fields.push({label: Translations.text("vault.fields.notes"), value: entry.notes, secret: true, multiline: true})
        for (const field of entry.fields ?? []) if (field.value != null) fields.push({label: field.name || Translations.text("vault.fields.custom"), value: field.value, secret: true})
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
    function copy(value, completed = null) {
        RbwService.copy(value, completed)
    }
    function back() { if (editing || deleting) { discard(); focusSearch() } else RbwService.close() }
    Component.onDestruction: discard()
    Connections {
        target: RbwService
        function onEntriesChanged() {
            root.selectFirst()
        }
        function onCleared() { root.discard() }
        function onSaved() { root.discard(); root.notice = Translations.text("vault.status.saved") }
        function onGenerated(value) { if (root.editing) editor.setPassword(value) }
        function onCopied() { root.notice = Translations.text("vault.status.copied") }
        function onSelectingChanged() {
            root.detailBusyShown = false
            if (RbwService.selecting) detailBusyDelay.restart()
            else detailBusyDelay.stop()
        }
    }
    UI.PanelShortcut {
        owner: root
        action: "edit"
        actionEnabled: root.visible && RbwService.visible && root.detailReady && root.editable && !RbwService.busy && !root.editing && !root.deleting
        onActivated: root.edit()
    }
    UI.PanelShortcut { owner: root; action: "search"; actionEnabled: !root.editing && !root.deleting; onActivated: root.focusSearch() }
    Keys.onPressed: event => {
        UI.Keybinds.handleCancel(event, () => root.back())
    }
    Column {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.tooltipPaddingWidth
        anchors.bottomMargin: footer.height
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
                retainPanelWhileEditing: false
                enabled: !root.editing && !root.deleting
                placeholderText: Translations.text("vault.search.placeholder")
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
                UI.ActionButton { keyAction: "refresh"; glyph: Theme.refreshIcon; hint: Translations.text("vault.actions.syncHint"); enabled: !RbwService.busy && !root.editing; onClicked: RbwService.reload(true) }
                UI.ActionButton { objectName: "vaultLock"; keyAction: "vault.lock"; glyph: Theme.lockIcon; hint: Translations.text("vault.actions.lockHint"); enabled: !RbwService.busy; onClicked: RbwService.lock() }
                UI.ActionButton { objectName: "vaultAdd"; keyAction: "add"; glyph: Theme.addIcon; hint: Translations.text("vault.actions.newLogin"); enabled: !RbwService.busy && !root.editing && !root.deleting; onClicked: root.newLogin() }
            }
        }
        Row {
            objectName: "vaultFilters"
            width: parent.width
            spacing: Theme.controlSpacing
            UI.ComboSelector {
                toggleObjectName: "vaultFolderToggle"
                choicesObjectName: "vaultFolderChoices"
                label: Translations.text("vault.folder.label", [selectedDescription])
                hint: Translations.text("vault.folder.filterHint")
                width: (parent.width - Theme.controlSpacing) / 2
                compact: true
                enabled: !root.editing && !root.deleting && (!RbwService.busy || RbwService.selecting)
                options: [{name: "", description: Translations.text("vault.folder.all")}, ...RbwService.folders.map(value => ({name: value, description: value}))]
                selectedName: root.folderFilter
                onSelected: name => { root.folderFilter = name; root.selectFirst() }
            }
            UI.ComboSelector {
                width: (parent.width - Theme.controlSpacing) / 2
                compact: true
                enabled: !root.editing && !root.deleting && (!RbwService.busy || RbwService.selecting)
                options: [{name: "Login", description: Translations.text("vault.types.logins")}, ...[...new Set(RbwService.entries.map(row => row.type).filter(value => value && value !== "Login"))].sort().map(value => ({name: value, description: value === "Note" ? Translations.text("vault.fields.notes") : value}))]
                toggleObjectName: "vaultTypeToggle"
                choicesObjectName: "vaultTypeChoices"
                label: Translations.text("vault.type.label", [selectedDescription])
                hint: Translations.text("vault.type.filterHint")
                selectedName: root.typeFilter
                onSelected: name => { root.typeFilter = name; root.selectFirst() }
            }
        }
        Row {
            width: parent.width
            height: Math.max(100, content.height - y)
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
                    property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: details }
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
                        x: Theme.controlSpacing + Theme.scrollbarGutter
                        y: Theme.controlSpacing
                        width: Math.max(0, details.width - (Theme.scrollbarGutter + Theme.controlSpacing) * 2)
                        spacing: Theme.controlSpacing
                        UI.Text { centerVertical: false; width: parent.width; textFormat: Text.PlainText; wrapMode: Text.Wrap; visible: !!RbwService.detail; color: Theme.inactive; text: RbwService.detail?.folder ?? Translations.text("vault.folder.none") }
                        VaultEntryDetails {
                            width: parent.width
                            visible: !root.editing && !root.deleting
                            enabled: root.detailReady && !RbwService.busy
                            fields: root.detailRows
                            onCopyRequested: (value, completed) => root.copy(value, completed)
                        }
                        Column {
                            width: parent.width
                            visible: root.deleting
                            spacing: Theme.controlSpacing
                            UI.Text { centerVertical: false; width: parent.width; textFormat: Text.PlainText; wrapMode: Text.Wrap; text: Translations.text("vault.delete.confirm",[RbwService.detail?.name ?? ""]); color: Theme.warning }
                        }
                        VaultEntryEditor {
                            id: editor
                            width: parent.width
                            visible: root.editing
                            enabled: !RbwService.busy
                            adding: root.adding
                            onCopyRequested: (value, completed) => root.copy(value, completed)
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
                        UI.ActionButton { objectName: "vaultEdit"; glyph: Theme.editIcon; hintAction: "edit"; hint: Translations.text("vault.actions.editHint"); visible: root.editable; enabled: root.detailReady && root.editable && !RbwService.busy; onClicked: root.edit() }
                        UI.ActionButton { objectName: "vaultDelete"; glyph: Theme.deleteIcon; hint: Translations.text("vault.actions.deleteHint"); fillColor: Theme.urgent; enabled: root.detailReady && !RbwService.busy; onClicked: root.deleting = true }
                    }
                    UI.EditorActions {
                        objectName: "vaultEditorActions"
                        anchors.right: parent.right
                        visible: root.editing
                        submitObjectName: "vaultSave"
                        cancelObjectName: "vaultCancel"
                        submitGlyph: root.adding ? Theme.addIcon : Theme.checkIcon
                        submitHint: Translations.text(root.adding ? "vault.actions.create" : "common.actions.saveChanges")
                        submitEnabled: !RbwService.busy && (!root.adding || editor.validTitle)
                        cancelEnabled: !RbwService.busy
                        onSubmitted: root.save()
                        onCancelled: { root.discard(); root.focusSearch() }
                    }
                    UI.EditorActions {
                        anchors.right: parent.right
                        visible: root.deleting
                        submitKeyAction: ""
                        submitGlyph: Theme.deleteIcon
                        submitColor: Theme.urgent
                        submitHint: Translations.text("vault.actions.deleteHint")
                        submitEnabled: !RbwService.busy
                        cancelEnabled: !RbwService.busy
                        onSubmitted: RbwService.remove()
                        onCancelled: root.deleting = false
                    }
                }
            }
        }
    }
    Column {
        id: footer
        objectName: "vaultFooter"
        x: Theme.tooltipPaddingWidth
        width: parent.width - Theme.tooltipPaddingWidth * 2
        anchors.bottom: parent.bottom
        spacing: Theme.controlSpacing
        Item {
            id: footerFeedback
            width: parent.width
            height: Math.max(formHints.visible ? Math.max(Theme.controlHeight, formHints.implicitHeight) : 0, status.visible ? Math.max(Theme.controlHeight, status.implicitHeight) : 0)
            UI.ShortcutHints {
                id: formHints
                objectName: "vaultFormHints"
                width: parent.width
                height: parent.height
                visible: !status.visible && text.length > 0
                panelKey: root.editing ? "editing" : "vault"
                availableActions: root.deleting ? [] : root.editing ? ["save"] : ["search", "add", "refresh", "vault.lock"]
                    .concat(root.editable && root.detailReady ? ["edit"] : [])
                actionOverrides: ({refresh: {label: Translations.text("hints.sync")}})
            }
            UI.Text {
                id: status
                objectName: "vaultStatus"
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                width: parent.width
                centerVertical: false
                font.pixelSize: Theme.fontSize - 1
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                visible: text.length > 0
                text: (RbwService.busy && !RbwService.selecting) || root.detailBusyShown ? Translations.text("common.status.working") : RbwService.error || root.notice
                color: RbwService.error ? Theme.warning : Theme.inactive
            }
        }
    }
}
