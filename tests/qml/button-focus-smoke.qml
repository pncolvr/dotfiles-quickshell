pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/theme/ui" as UI
import "../../src/modules/system/audio"
import "../../src/modules/media"

Scope {
    id: root
    property bool failed: false
    property int actionClicks: 0
    property int audioClicks: 0
    function check(condition, message) {
        if (!condition) { failed = true; console.error("BUTTON FOCUS FAIL: " + message) }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        if (item instanceof UI.ComboSelector && item.choicesObjectName === name) return item.choicesView
        for (const child of item.children ?? []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    function checkButton(button, persistentBorder = false) {
        button.forceActiveFocus(Qt.TabFocusReason)
        check(button.visualFocus && button.background.border.width === 1, "keyboard focus has a visible border")
        events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        check(!button.visualFocus && button.background.border.width === (persistentBorder ? 1 : 0),
            "click removes keyboard focus while preserving the control's normal border")
    }
    function checkSelector(combo) {
        const toggle = root.find(combo, combo.toggleObjectName) as QC.Button;
        events.mouseMove(toggle, toggle.width / 2, toggle.height / 2, 0);
        root.check((toggle.background as Rectangle).color.a === 1, "combo toggle hover stays opaque");
        combo.expanded = true;
        events.wait(150);
        const choices = root.find(combo, combo.choicesObjectName) as ListView;
        const option = choices.itemAtIndex(0) as QC.ItemDelegate;
        events.mouseMove(option, option.width / 2, option.height / 2, 0);
        events.wait(20);
        root.check(option.hovered && (option.background as Rectangle).color.a === 1,
            "generic, device and profile dropdown hover rows stay opaque");
        option.forceActiveFocus(Qt.TabFocusReason);
        root.check(option.activeFocus && (option.background as Rectangle).color.a === 1,
            "keyboard-focused dropdown rows stay opaque");
        combo.expanded = false;
        events.wait(150);
    }
    QtObject {
        id: mockAudio
        property bool profileBusy: false
        function setProfile(card, name) {}
    }
    FloatingWindow {
        Test.TestCase { id: events; when: false }
        visible: true
        implicitWidth: 420
        implicitHeight: 600
        Column {
            anchors.fill: parent
            spacing: 8
            UI.ActionButton { id: action; glyph: "x"; hint: "Action"; onClicked: root.actionClicks++ }
            AudioButton { id: audio; glyph: "x"; hint: "Audio"; onClicked: root.audioClicks++ }
            AudioSelector { id: selector; width: 350; options: [{name: "banana", description: "Banana", available: true}]; selectedName: "banana" }
            UI.ComboSelector { id: generic; width: 350; options: [{name: "banana", description: "Banana"}]; selectedName: "banana" }
            AudioProfileSelector { id: profile; width: 350; card: ({activeProfile:"banana", profiles:[{name:"banana", description:"Banana", available:true}]}); audioService: mockAudio }
            AudioVolumeSlider { id: slider; width: 350; volume: 0.5 }
            TwitchUserSection { id: section; width: 350; title: "Banana"; users: [{login: "banana", online: false}]; columns: 1; expanded: false }
            UI.TabBar { id: tabs; labels: ["Banana", "Potato"]; width: 350 }
        }
    }
    Timer {
        interval: 150
        running: true
        onTriggered: {
            root.checkButton(action)
            root.checkButton(audio)
            root.check(root.actionClicks === 1 && root.audioClicks === 1, "focus handling preserves mouse activation")
            action.forceActiveFocus(Qt.TabFocusReason)
            events.keyClick(Qt.Key_Space, Qt.NoModifier, 0)
            root.check(root.actionClicks === 2 && action.visualFocus && (action.background as Rectangle).border.width === 1,
                "keyboard activation preserves its focus indicator")
            const toggle = root.find(selector, "selectorToggle")
            // ComboSelector deliberately keeps its normal one-pixel outline.
            root.checkButton(toggle, true)
            root.check(selector.expanded, "selector can remain open without a persistent focus border")
            selector.expanded = false
            root.checkSelector(generic)
            root.checkSelector(selector)
            root.checkSelector(profile)
            slider.forceActiveFocus(Qt.TabFocusReason)
            root.check(slider.visualFocus && (slider.handle as Rectangle).border.width === 2, "slider keyboard focus remains visible")
            events.mouseClick(slider, slider.width / 2, slider.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
            root.check(!slider.visualFocus && (slider.handle as Rectangle).border.width === 0, "slider click leaves no focus outline")
            const heading = root.find(section, "toggleTwitchUserSection")
            heading.forceActiveFocus(Qt.TabFocusReason)
            events.mouseClick(heading, heading.width / 2, heading.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
            root.check(!heading.visualFocus && section.expanded, "Twitch header toggles without keeping keyboard highlighting")
            const tab = tabs.itemAt(1) as QC.TabButton
            tab.forceActiveFocus(Qt.TabFocusReason)
            events.mouseClick(tab, tab.width / 2, tab.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
            root.check(!tab.visualFocus && tab.checked, "tab selection works without a mouse focus outline")
            if (!root.failed) console.log("PASS: pointer clicks clear focus decorations while keyboard focus and control states remain available")
            Qt.quit()
        }
    }
}
