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
    property bool notesRevealed: false
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
    readonly property bool editable: RbwService.detail && (RbwService.detail.data === null || RbwService.detail.data.hasOwnProperty("password"))
    readonly property var detailRows: {
        const entry = RbwService.detail
        if (!entry) return []
        const fields = (entry.data?.uris ?? []).map(uri => ({label: "Website", value: uri.uri, secret: false}))
        fields.push(...Object.entries(entry.data ?? {}).filter(([key, value]) => value !== null && key !== "uris")
            .map(([key, value]) => ({label: key.replace(/_/g, " "), value: String(value), secret: key !== "username"})))
        if (entry.notes) fields.push({label: "Notes", value: entry.notes, secret: true})
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
    function discard() { editing = false; adding = false; deleting = false; notesRevealed = false; title.clear(); username.clear(); password.clear(); password.revealed = false; urls.clear(); folder.clear(); notes.clear() }
    function newLogin() {
        if (RbwService.busy || editing) return
        RbwService.clear(); discard(); editing = true; adding = true
        Qt.callLater(() => title.forceActiveFocus())
    }
    function edit() {
        if (!editable || RbwService.busy) return
        discard(); editing = true
        password.text = RbwService.detail.data?.password ?? ""
        notes.text = RbwService.detail.notes ?? ""
        Qt.callLater(() => RbwService.detail.data === null ? notes.forceActiveFocus() : password.forceActiveFocus())
    }
    function save() {
        RbwService.save({id: adding ? "" : RbwService.detail?.id, name: title.text, username: username.text,
            password: password.text, notes: notes.text, folder: folder.text,
            uris: urls.text.split("\n").map(value => value.trim()).filter(Boolean)})
    }
    function copy(value) {
        if (!value) return
        RbwService.copy(value); notice = "Copied; expires after 30 seconds."
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
        function onGenerated(value) { if (root.editing) password.text = value }
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
            ListView {
                id: list
                objectName: "vaultList"
                width: parent.width * 0.38
                height: parent.height
                clip: true
                model: root.rows
                enabled: !root.editing && !root.deleting && (!RbwService.busy || RbwService.selecting)
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                topMargin: Theme.controlSpacing
                bottomMargin: Theme.controlSpacing
                QC.ScrollBar.vertical: UI.ScrollBar {}
                Rectangle {
                    parent: list
                    anchors.fill: parent
                    anchors.margins: 1
                    z: 1
                    color: "transparent"
                    radius: Theme.iconButtonRadius
                    border.width: 1
                    border.color: Theme.empty
                }
                delegate: QC.ItemDelegate {
                    id: entryRow
                    required property var modelData
                    required property int index
                    width: list.width
                    padding: Theme.pickerRowPadding
                    leftPadding: Theme.controlFieldPadding
                    rightPadding: Theme.controlFieldPadding + Theme.scrollbarWidth
                    height: Math.max(Theme.controlHeight, contentItem.implicitHeight + topPadding + bottomPadding)
                    objectName: "vaultEntry-" + modelData.id
                    onClicked: { list.currentIndex = index; RbwService.select(modelData.id) }
                    background: Rectangle { color: entryRow.index === list.currentIndex ? Theme.alternateBackground : "transparent"; radius: Theme.iconButtonRadius }
                    contentItem: Column {
                        UI.Text { centerVertical: false; width: parent.width; textFormat: Text.PlainText; text: entryRow.modelData.name; color: entryRow.index === list.currentIndex ? Theme.accent : Theme.text; elide: Text.ElideRight }
                        UI.Text { centerVertical: false; width: parent.width; visible: text.length > 0; textFormat: Text.PlainText; text: [entryRow.modelData.user, entryRow.modelData.folder].filter(Boolean).join(" · "); color: entryRow.index === list.currentIndex ? Theme.accent : Theme.inactive; elide: Text.ElideRight }
                    }
                    Keys.onReturnPressed: RbwService.select(modelData.id)
                    Keys.onEnterPressed: RbwService.select(modelData.id)
                }
                UI.Text { centerVertical: false; anchors.centerIn: parent; text: "No entries"; visible: !root.rows.length && !RbwService.busy }
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
                        Column {
                            width: parent.width
                            visible: !root.editing && !root.deleting
                            enabled: root.detailReady && !RbwService.selecting
                            spacing: Theme.controlSpacing
                            Repeater {
                                model: root.detailRows
                                Column {
                                    id: valueRow
                                    required property var modelData
                                    width: parent.width
                                    spacing: 4
                                    UI.Text { centerVertical: false; width: parent.width; text: valueRow.modelData.label; textFormat: Text.PlainText; color: Theme.inactive }
                                    Row {
                                        width: parent.width
                                        spacing: Theme.controlSpacing
                                        VaultSecretField {
                                            id: valueField
                                            objectName: "vaultDetailField-" + valueRow.modelData.label
                                            width: parent.width - Theme.actionButtonWidth - Theme.controlSpacing
                                            readOnly: true
                                            text: valueRow.modelData.value
                                            revealed: !valueRow.modelData.secret
                                            Connections {
                                                target: RbwService
                                                function onSelectedIdChanged() { valueField.revealed = !valueRow.modelData.secret }
                                            }
                                        }
                                        UI.ActionButton { glyph: Theme.copyIcon; hint: "Copy " + valueRow.modelData.label; onClicked: root.copy(valueRow.modelData.value) }
                                    }
                                }
                            }
                        }
                        Column {
                            width: parent.width
                            visible: root.deleting
                            spacing: Theme.controlSpacing
                            UI.Text { centerVertical: false; width: parent.width; textFormat: Text.PlainText; wrapMode: Text.Wrap; text: "Delete “" + (RbwService.detail?.name ?? "") + "”? This removes the vault entry."; color: Theme.warning }
                        }
                        Column {
                            width: parent.width
                            visible: root.editing
                            enabled: !RbwService.busy
                            spacing: Theme.controlSpacing
                            UI.InputField { id: title; objectName: "vaultTitle"; width: parent.width; visible: root.adding; placeholderText: "Entry title"; pauseTooltipDismissal: false }
                            QC.TextArea { id: urls; width: parent.width; visible: root.adding; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.bold: Theme.fontBold; padding: Theme.controlFieldPadding; textFormat: TextEdit.PlainText; placeholderTextColor: Theme.inactive; placeholderText: "Website URLs, one per line"; color: Theme.text; wrapMode: TextEdit.Wrap; background: Rectangle { color: Theme.alternateBackground; radius: Theme.iconButtonRadius } }
                            UI.InputField { id: username; width: parent.width; visible: root.adding; placeholderText: "Username / email"; pauseTooltipDismissal: false }
                            Item {
                                width: parent.width
                                height: Theme.controlHeight
                                visible: password.visible
                                UI.Text {
                                    anchors.left: parent.left
                                    anchors.right: length.left
                                    anchors.rightMargin: Theme.controlSpacing
                                    text: "Password"
                                    color: Theme.inactive
                                    elide: Text.ElideRight
                                }
                                UI.InputField {
                                    id: length
                                    anchors.right: passwordActions.left
                                    anchors.rightMargin: Theme.controlSpacing
                                    width: 60
                                    text: "24"
                                    placeholderText: "Length"
                                    Accessible.name: "Generated password length"
                                    pauseTooltipDismissal: false
                                    validator: IntValidator { bottom: 8; top: 128 }
                                }
                                Row {
                                    id: passwordActions
                                    anchors.right: parent.right
                                    spacing: Theme.controlSpacing
                                    UI.ActionButton { glyph: Theme.retryIcon; hint: "Generate password"; onClicked: RbwService.generate(Number(length.text)) }
                                    UI.ActionButton { glyph: Theme.copyIcon; hint: "Copy password"; onClicked: root.copy(password.text) }
                                }
                            }
                            VaultSecretField { id: password; objectName: "vaultPassword"; width: parent.width; visible: root.adding || RbwService.detail?.data !== null; placeholderText: "Password" }
                            UI.InputField { id: folder; width: parent.width; visible: root.adding; placeholderText: "Folder (optional, existing or new)"; pauseTooltipDismissal: false }
                            UI.ComboSelector { width: parent.width; visible: root.adding && RbwService.folders.length > 0; compact: true; options: RbwService.folders.map(value => ({name: value, description: value})); selectedName: folder.text; placeholder: "Choose an existing folder"; onSelected: name => folder.text = name }
                            UI.Text { centerVertical: false; text: "Notes"; color: Theme.inactive }
                            QC.TextArea {
                                id: notes
                                objectName: "vaultNotes"
                                width: parent.width
                                implicitHeight: root.notesRevealed ? Math.max(Theme.controlHeight * 3, contentHeight + topPadding + bottomPadding) : Theme.controlHeight * 3
                                padding: Theme.controlFieldPadding
                                rightPadding: notesEye.width + Theme.controlFieldPadding * 2
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: Theme.fontBold
                                textFormat: TextEdit.PlainText
                                placeholderText: root.notesRevealed ? "Notes (optional)" : ""
                                placeholderTextColor: Theme.inactive
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.text
                                color: root.notesRevealed ? Theme.text : "transparent"
                                readOnly: !root.notesRevealed
                                wrapMode: TextEdit.Wrap
                                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                background: Rectangle { color: Theme.alternateBackground; radius: Theme.iconButtonRadius; border.width: 1; border.color: notes.activeFocus ? Theme.accent : Theme.empty }
                                UI.Text { objectName: "vaultNotesMask"; centerVertical: false; anchors.fill: parent; anchors.margins: Theme.controlFieldPadding; anchors.rightMargin: notes.rightPadding; visible: !root.notesRevealed; text: notes.text.length ? "••••••••" : "Notes (optional)"; color: notes.text.length ? Theme.text : Theme.inactive }
                                UI.ActionButton {
                                    id: notesEye
                                    objectName: "vaultNotesEye"
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.controlFieldPadding
                                    y: 2
                                    implicitWidth: Theme.controlHeight
                                    implicitHeight: Theme.controlHeight - 4
                                    glyph: root.notesRevealed ? Theme.eyeSlashIcon : Theme.eyeIcon
                                    hint: root.notesRevealed ? "Hide notes" : "Reveal notes to edit"
                                    checkable: true
                                    checked: root.notesRevealed
                                    onClicked: { root.notesRevealed = !root.notesRevealed; notes.forceActiveFocus() }
                                }
                                Keys.onShortcutOverride: event => { if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true }
                                Keys.onPressed: event => { if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true }
                            }
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
                        UI.ActionButton { objectName: "vaultEdit"; glyph: Theme.editIcon; hint: "Edit entry"; enabled: root.detailReady && root.editable && !RbwService.busy; onClicked: root.edit() }
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
                        submitEnabled: !RbwService.busy && (!root.adding || title.text.trim().length > 0)
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
