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

Scope {
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
    function check(ok, message) { if (!ok) { failed = true; console.error('KEYBINDS FAIL:',message) } }
    function key(group, action, sequence) {
        const value = Object.assign({},settings.keybinds)
        value[group] = Object.assign({},value[group],{[action]:sequence})
        settings.keybinds = value
    }
    function focusBorder(item: var): int { return item.background.border.width }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 600; implicitHeight: 650
        color: Theme.tooltipBackground
        Column {
            id: panel
            property bool nativeDialogOpen: false
            width: parent.width
            spacing: 6
            UI.TabBar { id: tabs; width: parent.width; labels: ['First','Second','Third']; onTabClicked: root.tabActions++ }
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
            if (!root.failed) console.log('PASS: configured panel actions, dynamic hints, text editing, child scopes, focus feedback and scrolling')
            Qt.quit()
        }
    }
}
