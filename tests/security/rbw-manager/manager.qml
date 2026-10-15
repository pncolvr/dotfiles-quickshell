pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../../src/services"
import "../../../src/modules/vault"
import "../../../src/theme"
import "../../../src/theme/ui" as UI
Scope {
    id: root
    function findVisual(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const result = root.findVisual(child, name)
            if (result) return result
        }
        return null
    }
    Test.TestResult { id: objects }
    Test.TestEvent { id: events }
    FloatingWindow {
        visible: true
        implicitWidth: 780
        implicitHeight: 760
        VaultPanel { id: panel; anchors.fill: parent }
    }
    IpcHandler {
        target: "rbwtest"
        function snapshot(): string {
            const field = objects.findChild(panel, "vaultPassword") as UI.SecretField
            const actions = objects.findChild(panel, "vaultEditorActions") as UI.EditorActions
            const hints = objects.findChild(panel, "vaultFormHints") as UI.ShortcutHints
            const notes = root.findVisual(panel, "vaultDetailNotes")
            const mask = root.findVisual(panel, "vaultDetailNotesMask") as UI.Text
            const filters = objects.findChild(panel, "vaultFilters") as Row
            const list = objects.findChild(panel, "vaultList") as ListView
            const details = objects.findChild(panel, "vaultDetails") as Item
            const detailScroll = objects.findChild(panel,"vaultDetailScroll") as Flickable
            const detailActions = objects.findChild(panel,"vaultDetailActions") as Item
            const detailPassword = root.findVisual(panel,"vaultDetailField-password") as UI.SecretField
            const detailTotp = root.findVisual(panel,"vaultDetailField-TOTP secret") as UI.SecretField
            const totpCopy = root.findVisual(panel,"vaultCopyTotp") as UI.ActionButton
            const edit = objects.findChild(panel,"vaultEdit") as UI.ActionButton
            const remove = objects.findChild(panel,"vaultDelete") as UI.ActionButton
            const toggle = objects.findChild(panel, "vaultFolderToggle") as QC.Button
            const add = objects.findChild(panel,"vaultAdd") as UI.ActionButton
            const lock = objects.findChild(panel,"vaultLock") as UI.ActionButton
            const status = objects.findChild(panel,"vaultStatus") as UI.Text
            const choices = objects.findChild(panel, "vaultFolderChoices") as ListView
            const typeChoices = objects.findChild(panel, "vaultTypeChoices") as ListView
            const typeToggle = objects.findChild(panel, "vaultTypeToggle") as QC.Button
            return JSON.stringify({statusVisible:status.visible,hintsVisible:hints.visible,
                addVisible:add.visible,addEnabled:add.enabled,
                addBesideLock:add.x >= lock.x + lock.width && add.y === lock.y,
                typeExpanded:(typeToggle.parent as UI.ComboSelector).expanded,typeChoiceReady:!!typeChoices.itemAtIndex(1),
                statusBelowActions:status.mapToItem(panel,0,0).y >= details.mapToItem(panel,0,details.height).y,
                statusRight:status.horizontalAlignment===Text.AlignRight,
                listBottomAligned: Math.abs(list.mapToItem(panel,0,list.height).y - details.mapToItem(panel,0,details.height).y) < 1,
                filterGap: list.mapToItem(panel,0,0).y - filters.mapToItem(panel,0,0).y - filters.height,
                filterSpacing:filters.spacing, comboFramed:(toggle.background as Rectangle).border.width === 1,
                folderExpanded:(toggle.parent as UI.ComboSelector).expanded, folderChoiceReady:!!choices.itemAtIndex(2),
                formActionsRight: actions.parent.parent === details
                    && Math.abs(actions.x + actions.width - actions.parent.width) < 1
                    && actions.mapToItem(details,0,actions.height).y <= details.height,
                hintsBelowActions: hints.mapToItem(panel,0,0).y >= actions.mapToItem(panel,0,0).y + actions.height,
                notesMaskClean: !!notes && mask.visible && notes.height >= Theme.controlHeight * 6,
                notesRevealed: notes?.revealed ?? false, notesEditable: !!notes && !notes.readOnly,
                notesIntact: !!notes && notes.text === RbwService.detail?.notes,
                noteEditVisible: edit.visible, notesTall: !!notes && notes.height >= Theme.controlHeight * 6,
                visible:RbwService.visible,busy:RbwService.busy,count:RbwService.entries.length,
                selectedFirst:RbwService.detail?.id === panel.rows[0]?.id && (objects.findChild(panel,"vaultList") as ListView).currentIndex === 0,
                details:!!RbwService.detail,editing:panel.editing,adding:panel.adding,deleting:panel.deleting,
                detailScrollHeight:detailScroll.height,detailActionsVisible:detailActions.visible,
                detailMasked:!detailPassword || detailPassword.echoMode===TextInput.Password,
                totpPresent:!!detailTotp && detailTotp.text.length>0,
                totpMasked:!detailTotp || detailTotp.echoMode===TextInput.Password,
                totpCopyEnabled:!!totpCopy?.enabled,
                detailEnabled:!!detailPassword?.enabled,detailActionsEnabled:edit.enabled || remove.enabled,
                detailId:RbwService.detail?.id ?? "",selectionMatches:!!RbwService.detail && RbwService.detail.id === panel.selectedEntryId,
                draftEmpty:field.text.length===0,masked:field.echoMode===TextInput.Password,
                hasError:RbwService.error.length>0,rows:panel.rows.length,typeFilter:panel.typeFilter,
                noteSelected:RbwService.detail?.id === "22222222-2222-2222-2222-222222222222",
                copying:!!RbwService.clipboardOwner, checking:RbwService.checkingLock,
                statusHeight:(objects.findChild(panel,"vaultStatus") as UI.Text).height, listHeight:(objects.findChild(panel,"vaultList") as ListView).height,
                rowReady:!!(objects.findChild(panel,"vaultList") as ListView).itemAtIndex(0),
                listEnabled:(objects.findChild(panel,"vaultList") as ListView).enabled})
        }
        function open(): void { RbwService.open() }
        function close(): void { RbwService.close() }
        function select(): void { RbwService.clear(); RbwService.select("11111111-1111-1111-1111-111111111111") }
        function clickEntry(): void {
            const row = (objects.findChild(panel, "vaultList") as ListView).itemAtIndex(0) as QC.ItemDelegate
            events.mouseClick(row, row.width / 2, row.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
        function poll(): void { RbwService.checkLock() }
        function toggleFolder(): void {
            const toggle = objects.findChild(panel,"vaultFolderToggle") as QC.Button
            events.mouseClick(toggle,toggle.width/2,toggle.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function chooseWork(): void {
            const row = (objects.findChild(panel,"vaultFolderChoices") as ListView).itemAtIndex(2) as QC.ItemDelegate
            events.mouseClick(row,row.width/2,row.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function chooseAll(): void {
            const row = (objects.findChild(panel,"vaultFolderChoices") as ListView).itemAtIndex(0) as QC.ItemDelegate
            events.mouseClick(row,row.width/2,row.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function toggleType(): void {
            const toggle = objects.findChild(panel,"vaultTypeToggle") as QC.Button
            events.mouseClick(toggle,toggle.width/2,toggle.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function chooseType(name: string): void {
            const toggle = objects.findChild(panel,"vaultTypeToggle") as QC.Button
            const combo = toggle.parent as UI.ComboSelector
            const choices = objects.findChild(panel,"vaultTypeChoices") as ListView
            const row = choices.itemAtIndex(combo.options.findIndex(option => option.name === name)) as QC.ItemDelegate
            events.mouseClick(row,row.width/2,row.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function search(): void { const field = objects.findChild(panel,"vaultSearch") as UI.InputField; field.text="exlg" }
        function searchSecond(): void { (objects.findChild(panel,"vaultSearch") as UI.InputField).text="zebra" }
        function revealDetail(): void {
            const field = root.findVisual(panel,"vaultDetailField-password") as UI.SecretField
            const button = objects.findChild(field,"vaultEye") as UI.ActionButton
            events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function revealTotp(): void {
            const field = root.findVisual(panel,"vaultDetailField-TOTP secret") as UI.SecretField
            const button = objects.findChild(field,"vaultEye") as UI.ActionButton
            button.clicked()
        }
        function copyTotp(): void { (root.findVisual(panel,"vaultCopyTotp") as UI.ActionButton).clicked() }
        function copyTotpSecret(): void { (root.findVisual(panel,"vaultCopyTotpSecret") as UI.ActionButton).clicked() }
        function searchMissing(): void { (objects.findChild(panel,"vaultSearch") as UI.InputField).text="no such entry" }
        function moveDown(): void {
            (objects.findChild(panel,"vaultSearch") as UI.InputField).forceActiveFocus()
            events.keyClick(Qt.Key_Down,Qt.NoModifier,0)
        }
        function moveUp(): void {
            (objects.findChild(panel,"vaultSearch") as UI.InputField).forceActiveFocus()
            events.keyClick(Qt.Key_Up,Qt.NoModifier,0)
        }
        function resetSearch(): void { const field = objects.findChild(panel,"vaultSearch") as UI.InputField; field.clear() }
        function newLogin(): void {
            const button = objects.findChild(panel,"vaultAdd") as UI.ActionButton
            events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function typeDraft(): void {
            (objects.findChild(panel,"vaultTitle") as UI.InputField).text="Synthetic created login";
            (objects.findChild(panel,"vaultPassword") as UI.SecretField).text="SYNTHETIC_DRAFT_PASSWORD";
        }
        function eye(): void {
            const field = objects.findChild(panel,"vaultPassword") as UI.SecretField
            const button = objects.findChild(field,"vaultEye") as UI.ActionButton
            events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function notesEye(): void {
            const button = root.findVisual(panel,"vaultDetailNotesEye") as UI.ActionButton
            button.clicked()
        }
        function typeNotes(): void {
            const notes = root.findVisual(panel,"vaultDetailNotes") as QC.TextArea
            notes.forceActiveFocus()
            events.keyClick(Qt.Key_A,Qt.NoModifier,0)
        }
        function generate(): void { RbwService.generate(24) }
        function preview(): void { panel.grabToImage(result => result.saveToFile(Quickshell.env("RBW_TEST_ROOT") + "/form.png")) }
        function save(): void {
            const button = objects.findChild(panel, "vaultSave") as UI.ActionButton
            events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
        function cancel(): void {
            const button = objects.findChild(panel,"vaultCancel") as UI.ActionButton
            events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function edit(): void {
            const button = objects.findChild(panel,"vaultEdit") as UI.ActionButton
            events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function deleteEntry(): void {
            const button = objects.findChild(panel,"vaultDelete") as UI.ActionButton
            events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
        function confirmDelete(): void { RbwService.remove() }
        function back(): void { panel.forceActiveFocus(); events.keyClick(Qt.Key_Escape,Qt.NoModifier,0) }
        function copy(): void { RbwService.copy("SYNTHETIC_COPY_PASSWORD") }
        function expireCopy(): void { const timer=RbwService.clipboardOwner.expiryTimer as Timer; timer.interval=40; timer.restart() }
        function lock(): void { RbwService.lock() }
    }
}
