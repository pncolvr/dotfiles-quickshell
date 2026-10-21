pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/ui" as UI
import "../../src/theme"
import "../../src/config"
import "../../src/services"
import "../../src/modules/system/audio"

WorkerScope {
    id: root
    property var settings: Config
    property var audio: AudioService
    property bool failed: false
    property int refreshes: 0
    property int additions: 0
    property int saves: 0
    property int tabActions: 0
    property int previousActions: 0
    property int muteActions: 0
    property int cancellations: 0
    function check(ok, message) { if (!ok) { failed = true; console.error('KEYBINDS FAIL:',message) } }
    function key(group, action, sequence) {
        const value = Object.assign({},settings.keybinds)
        value[group] = Object.assign({},value[group],{[action]:sequence})
        settings.keybinds = value
    }
    function focusBorder(item: var): int { return item.background.border.width }
    function tabsCentered() {
        const first = tabs.itemAt(0), last = tabs.itemAt(tabs.count - 1)
        const left = first.mapToItem(tabs,0,0).x
        const right = last.mapToItem(tabs,last.width,0).x
        return Math.abs((left + right) / 2 - tabs.width / 2) < 1
    }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 600; implicitHeight: 650
        color: Theme.tooltipBackground
        Column {
            id: panel
            Keys.onPressed: event => UI.Keybinds.handleCancel(event, () => root.cancellations++)
            property bool nativeDialogOpen: false
            width: parent.width
            spacing: 6
            UI.TabBar { id: tabs; width: parent.width; labels: ['First','Second','Third']; onTabClicked: root.tabActions++ }
            UI.PanelFocusScope {
                id: cancelScope
                width: parent.width
                height: 30
                onDismissRequested: root.cancellations++
                UI.InputField { id: cancelInput; width: parent.width; text: "Child field" }
            }
            UI.ShortcutHints { id: cancelHint; width: parent.width; closingHint: UI.Keybinds.cancelHint() }
            UI.SearchField { id: search; objectName: 'search'; width: parent.width; text: 'Select this text' }
            UI.ActionButton { id: refresh; label: 'Refresh'; hint: 'Refresh data'; keyAction: 'refresh'; onClicked: root.refreshes++ }
            UI.ActionButton { id: add; label: 'Add'; keyAction: 'add'; onClicked: root.additions++ }
            AudioButton { id: mute; glyph: Theme.volumeMutedIcon; hint: 'Mute'; keyAction: 'audio.mute'; onClicked: root.muteActions++ }
            UI.ActionButton { label: 'Previous'; keyAction: 'media.previousPlayer'; onClicked: root.previousActions++ }
            UI.EditorActions { onSubmitted: root.saves++ }
            UI.ComboSelector { id: combo; width: parent.width; options: [{name:'a',description:'First'},{name:'b',description:'Second'}]; selectedName:'a' }
            Flickable {
                id: scroll
                width: parent.width; height: 80
                contentHeight: rows.height
                clip: true
                Column {
                    id: rows
                    spacing: 8
                    Repeater { id: controls; model: 8; delegate: UI.ActionButton { required property int index; label: 'Row ' + index } }
                }
            }
        }
    }
    Timer {
        interval: 200; running: true
        onTriggered: {
            root.check(root.tabsCentered(),'normal tab buttons center as a compact group on their header line')
            tabs.actionTabs = true
            tabs.width = Qt.binding(() => tabs.implicitWidth)
            events.wait(20)
            root.check(tabs.leftPadding === 0 && tabs.rightPadding === 0
                && tabs.width === tabs.contentWidth
                && Math.abs(tabs.itemAt(0).mapToItem(tabs,0,0).x) < 1,'window action tabs retain their natural width and original alignment')
            tabs.actionTabs = false
            tabs.width = Qt.binding(() => panel.width)
            tabs.closeableTabs = [true]
            events.wait(20)
            root.check(root.tabsCentered(),'close buttons participate in centered tab sizing')
            tabs.width = 100
            events.wait(20)
            const tabView = tabs.contentItem as ListView
            root.check(tabs.leftPadding === 0 && tabs.rightPadding === 0 && tabView.contentWidth > tabView.width,
                'overflowing tabs use the header width without centering padding')
            tabs.navigateTab(tabs.count - 1)
            events.wait(20)
            const finalTab = tabs.itemAt(tabs.count - 1)
            const finalX = finalTab.mapToItem(tabs,0,0).x
            root.check(finalX >= -1 && finalX + finalTab.width <= tabs.width + 1,
                'keyboard navigation scrolls the last overflowing tab fully into view')
            tabs.width = Qt.binding(() => panel.width)
            tabs.closeableTabs = []
            tabs.setCurrentIndex(0)
            root.tabActions = 0
            events.wait(20)
            root.check(root.tabsCentered(),'tabs recenter when the header has room again')
            tabs.currentIndex = 2
            tabs.labels = ['Only']
            root.check(tabs.count === 1 && (tabs.itemAt(0) as QC.TabButton).text === 'Only' && tabs.currentIndex === 0,
                'shrinking tabs drops removed delegates and selects a valid tab')
            tabs.labels = []
            root.check(tabs.count === 0, 'empty tab lists release all delegates')
            tabs.labels = ['First','Second','Third']
            root.check(tabs.count === 3 && (tabs.itemAt(2) as QC.TabButton).text === 'Third',
                'tabs can be repopulated after clearing')
            search.forceActiveFocus()
            events.keyClick(Qt.Key_A,Qt.ControlModifier)
            root.check(search.selectedText === search.text && root.additions === 0,'Ctrl+A selects text, never adds')
            search.deselect(); search.cursorPosition = 5
            events.keyClick(Qt.Key_Left)
            root.check(search.cursorPosition === 4 && root.previousActions === 0,'text navigation wins over a panel arrow binding')
            events.keyClick(Qt.Key_N,Qt.ControlModifier)
            root.check(root.additions === 1,'configured Add works from search')
            events.keyClick(Qt.Key_M, Qt.ControlModifier | Qt.ShiftModifier)
            root.check(root.muteActions === 1 && mute.shortcutHint.includes('Ctrl+Shift+M'),
                'audio buttons share configured action and hint support')
            events.keyClick(Qt.Key_R,Qt.ControlModifier)
            root.check(root.refreshes === 1 && refresh.shortcutHint.includes('Ctrl+R'),'refresh button and shortcut share handler and hint')
            root.key('common','refresh','F6')
            events.keyClick(Qt.Key_R,Qt.ControlModifier)
            events.keyClick(Qt.Key_F6)
            root.check(root.refreshes === 2 && refresh.shortcutHint.includes('F6') && !refresh.shortcutHint.includes('Ctrl+R'),'binding change updates action and hint')
            refresh.enabled = false; events.keyClick(Qt.Key_F6)
            root.check(root.refreshes === 2,'disabled button disables shortcut')
            refresh.enabled = true; panel.nativeDialogOpen = true; events.keyClick(Qt.Key_F6)
            root.check(root.refreshes === 2,'native child dialog blocks owning shortcuts')
            panel.nativeDialogOpen = false
            refresh.visible = false; events.keyClick(Qt.Key_F6)
            root.check(root.refreshes === 2,'hidden owner disables shortcut')
            refresh.visible = true
            refresh.enabled = false; add.visible = false
            search.forceActiveFocus(Qt.TabFocusReason); events.keyClick(Qt.Key_Tab)
            root.check(mute.activeFocus, 'Tab skips disabled and hidden controls')
            events.keyClick(Qt.Key_Tab, Qt.ShiftModifier)
            root.check(search.activeFocus, 'Shift+Tab skips disabled and hidden controls')
            refresh.enabled = true; add.visible = true
            combo.expanded = true; events.wait(30); events.keyClick(Qt.Key_F6)
            root.check(root.refreshes === 2,'owned selection popup blocks panel actions')
            events.keyClick(Qt.Key_Escape); events.wait(20)
            search.forceActiveFocus(); events.keyClick(Qt.Key_S,Qt.ControlModifier)
            root.check(root.saves === 1,'Save uses editor action handler')
            const tab = tabs.itemAt(0) as QC.TabButton
            tab.forceActiveFocus(Qt.TabFocusReason)
            root.check(tab.visualFocus && root.focusBorder(tab) === 1,'tab focus has outline')
            root.settings.animationsEnabled = false
            root.check(root.focusBorder(tab) === 1,'focus remains visible without animations')
            root.audio.screencastActive = true
            root.check(root.focusBorder(tab) === 1,'focus remains visible during sharing')
            events.keyClick(Qt.Key_Right)
            root.check(tabs.currentIndex === 1 && root.tabActions === 1,'arrow tab activation runs the click action')
            events.keyClick(Qt.Key_Tab,Qt.ControlModifier)
            root.check(tabs.currentIndex === 2 && root.tabActions === 2,'configured next tab invokes same action')
            root.key('common','previousTab','Ctrl+Alt+P')
            events.keyClick(Qt.Key_P,Qt.ControlModifier | Qt.AltModifier)
            root.check(tabs.currentIndex === 1,'non-default previous-tab binding works')
            const last = controls.itemAt(7)
            last.forceActiveFocus(Qt.TabFocusReason); events.wait(20)
            const point = last.mapToItem(scroll,0,0)
            root.check(scroll.contentY > 0 && point.y >= 0 && point.y + last.height <= scroll.height + 1,'keyboard focus scrolls control into view')
            search.forceActiveFocus(); events.keyClick(Qt.Key_F,Qt.ControlModifier)
            root.check(search.activeFocus,'configured focus-search works')
            root.key('common','refresh','')
            events.keyClick(Qt.Key_F6)
            root.check(root.refreshes === 2,'empty binding disables shortcut')
            root.settings.panelHints = Object.assign({}, root.settings.panelHints, {test: ['clipboard.pin', 'clipboard.pinnedOnly', 'preview', 'edit']})
            cancelHint.panelKey = 'test'
            cancelHint.availableActions = ['clipboard.pin', 'clipboard.pinnedOnly', 'preview', 'edit']
            root.check(cancelHint.text.split(' · ').length === 4, 'explicit per-panel choices may exceed three')
            root.check(cancelHint.text.startsWith('Ctrl+P:') && cancelHint.text.endsWith('Edit'), 'configuration preserves hint order')
            root.key('clipboard','pin','F9')
            root.check(cancelHint.text.startsWith('F9:'), 'panel hints follow configured bindings')
            cancelHint.availableActions = ['edit']
            root.check(cancelHint.text === 'Ctrl+E: Edit', 'unavailable options are omitted')
            root.settings.panelHints = Object.assign({}, root.settings.panelHints, {test: []})
            root.check(cancelHint.text === '' && cancelHint.height === 0 && !cancelHint.visible, 'empty panel list removes footer space')
            cancelHint.panelKey = ''
            root.key('common','cancel','F8')
            root.check(cancelHint.text.includes('F8') && !cancelHint.text.includes('Esc'), 'cancel hint follows remapped binding')
            search.text = 'Keep until cancel'; search.forceActiveFocus()
            events.keyClick(Qt.Key_Escape)
            root.check(search.text === 'Keep until cancel' && root.cancellations === 0, 'old Escape no longer clears search or dismisses panels')
            events.keyClick(Qt.Key_F8)
            root.check(search.text === '' && root.cancellations === 0, 'search consumes remapped cancel before its parent')
            cancelInput.forceActiveFocus(); events.keyClick(Qt.Key_F8)
            root.check(root.cancellations === 1, 'unhandled remapped cancel bubbles to the panel once')
            combo.expanded = true; events.wait(30)
            events.keyClick(Qt.Key_Escape); events.wait(20)
            root.check(combo.expanded, 'popup no longer closes with hardcoded Escape')
            events.keyClick(Qt.Key_F8); events.wait(20)
            root.check(!combo.expanded && root.cancellations === 1, 'popup consumes configured cancel before panel dismissal')
            root.key('common','cancel','')
            root.check(cancelHint.text === '', 'disabled cancel hides its hint')
            cancelInput.forceActiveFocus(); events.keyClick(Qt.Key_F8); events.keyClick(Qt.Key_Escape)
            root.check(root.cancellations === 1, 'empty binding disables both old and remapped panel cancellation')
            combo.expanded = true; events.wait(30)
            events.keyClick(Qt.Key_F8); events.keyClick(Qt.Key_Escape); events.wait(20)
            root.check(combo.expanded && root.cancellations === 1, 'disabled cancel also leaves popups open')
            combo.expanded = false

            if (!root.failed) console.log('PASS: configured panel actions, dynamic hints, text editing, child scopes, focus feedback and scrolling')
            Qt.quit()
        }
    }
}
