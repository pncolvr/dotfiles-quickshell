pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/ui" as UI
import "../../src/theme"
import "../../src/modules/vault"

Scope {
    id: root
    property bool failed: false
    property int chosen: 0
    property int activated: 0
    property int clipboardActivated: 0
    property bool toggled: false
    property string vaultSelected: ""
    property int vaultActivations: 0
    readonly property var theme: Theme
    function check(ok, message) { if (!ok) { failed = true; console.error("ROW FAIL:",message) } }
    function click(row, modifiers = Qt.NoModifier) { events.mouseClick(row,row.width / 2,row.height / 2,Qt.LeftButton,modifiers,0) }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        visible: true
        implicitWidth: 900
        implicitHeight: 750
        Column {
            width: parent.width
            spacing: 8
            UI.PickerRow {
                id: picker
                width: 350
                current: true
                multiple: true
                entry: ({title:"Picker",subtitle:"Two lines"})
                onChosen: toggle => { root.chosen++; root.toggled = toggle }
                onActivated: root.activated++
            }
            UI.PickerRow {
                id: clipboard
                width: 350
                clipboard: true
                entry: ({title:"Clipboard"})
                onActivated: root.clipboardActivated++
            }
            VaultEntryList {
                id: vault
                width: 350
                height: 120
                entries: [{id:"one",name:"Login",user:"User",folder:"Work"},
                    {id:"two",name:"Note",user:"",folder:"Personal"}]
                onEntrySelected: entryId => { root.vaultSelected = entryId; root.vaultActivations++ }
            }
            UI.ManagementView {
                id: manage
                width: 780
                height: 300
                entries: [{id:"one",title:"One",subtitle:"Subtitle"},{id:"two",title:"Two",subtitle:"Other"}]
            }
            QC.ItemDelegate { id: nativeRow; width: 350; text: "Native row" }
            UI.TextBase { id: basic; text: "Base" }
            UI.Text { id: styled; centerVertical: false; text: "Styled" }
            UI.GlyphText { id: glyph; text: Theme.checkIcon }
            UI.InputField { id: input; width: 350; text: "Input" }
            UI.TextArea { id: multiline; width: 350; text: "Area" }
        }
    }
    Timer {
        interval: 150
        running: true
        onTriggered: {
            root.check(picker.cursorShape === Qt.PointingHandCursor,"picker inherits pointer cursor")
            const vaultRow = vault.itemAtIndex(1) as UI.SelectableRow
            const manageRow = manage.listView.itemAtIndex(1) as UI.SelectableRow
            root.check(!!vaultRow && !!manageRow,"Vault and Manage use the shared foundation")
            if (!vaultRow || !manageRow) { Qt.quit(); return }
            root.check(vaultRow.cursorShape === picker.cursorShape && manageRow.cursorShape === picker.cursorShape,"all row cursors share one policy")
            root.check(vaultRow.height >= vaultRow.contentItem.implicitHeight + vaultRow.topPadding + vaultRow.bottomPadding,"Vault preserves content-based height")
            root.check(manageRow.height === Theme.manageRowHeight,"Manage preserves uniform height")
            root.check(vaultRow.leftPadding === vaultRow.rightPadding && manageRow.leftPadding === manageRow.rightPadding,
                "Vault and Manage rows reserve equal side padding for scrollbars")
            root.click(picker,Qt.ControlModifier)
            root.check(root.chosen === 1 && root.activated === 1 && root.toggled,"picker preserves Ctrl-click selection and activation")
            picker.enabled = false
            root.click(picker)
            root.check(root.activated === 1,"disabled rows do not activate")
            picker.enabled = true
            root.click(clipboard)
            root.check(root.clipboardActivated === 0,"Clipboard single click only selects")
            events.mouseDoubleClickSequence(clipboard,clipboard.width / 2,clipboard.height / 2,Qt.LeftButton,Qt.NoModifier,0)
            root.check(root.clipboardActivated === 1,"Clipboard double click activates")
            root.click(nativeRow)
            const nativePointerFocus = nativeRow.activeFocus
            root.click(vaultRow)
            root.check(root.vaultSelected === "two" && vault.currentIndex === 1,"Vault pointer activation preserves selection")
            root.check(vaultRow.activeFocus === nativePointerFocus,"Vault preserves native pointer focus behavior")
            vaultRow.forceActiveFocus()
            const beforeEnter = root.vaultActivations
            root.vaultSelected = ""
            events.keyClick(Qt.Key_Return,Qt.NoModifier,0)
            root.check(root.vaultSelected === "two" && root.vaultActivations === beforeEnter + 1,"Vault Enter activates once focused")
            root.click(manageRow)
            root.check(manage.selectedId === "two","Manage click selects its entry")
            manage.editing = true
            root.click(manage.listView.itemAtIndex(0))
            root.check(manage.selectedId === "two","editing keeps the current entry")
            for (const item of [basic,styled,glyph,input,multiline]) {
                root.check(item.renderType === Theme.textRenderType,"shared text rendering")
                root.check(item.font.hintingPreference === Theme.fontHintingPreference,"shared font hinting")
            }
            root.theme.textRenderType = Text.QtRendering
            root.theme.fontHintingPreference = Font.PreferNoHinting
            for (const item of [basic,styled,glyph,input,multiline]) {
                root.check(item.renderType === Text.QtRendering && item.font.hintingPreference === Font.PreferNoHinting,
                    "one Theme change updates display text and both input bases")
            }
            root.check(glyph.font.family === Theme.fontFamilyIcons && !glyph.font.bold,"plain glyph preserves icon font metrics")
            if (!root.failed) console.log("PASS: shared row cursors, selection, activation, disabled/editing guards, focus, row sizing and text defaults")
            Qt.quit()
        }
    }
}
