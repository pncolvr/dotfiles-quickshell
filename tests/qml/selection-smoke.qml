pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import Quickshell.Wayland
import "../../src/theme"
import "../../src/ui" as UI
import "../../src/modules/system/audio"

Item {
    id: root
    property bool failed: false
    readonly property bool nativeTest: Quickshell.env("SELECTION_TEST_NATIVE") === "1"
    function check(value: bool, message: string) {
        if (!value) { failed = true; console.error("SELECTION FAIL: " + message) }
    }
    Rectangle { anchors.fill: parent; color: Theme.background }
    Item {
        id: body
        anchors.fill: parent
        property string selection: "chosen"
        property int commits: 0
        property int escapes: 0
        Keys.onEscapePressed: body.escapes++
        UI.ComboSelector {
            id: combo
            x: 16; y: 16; width: 300
            compact: true
            options: [{name:"first",description:"First option"}, {name:"disabled",description:"Unavailable",available:false},
                {name:"chosen",description:"Chosen option"}, {name:"last",description:"Last option"}]
            selectedName: body.selection
            onSelected: name => { body.selection = name; body.commits++ }
        }
        UI.InputField { id: following; x: 16; y: combo.y + combo.height + 10; width: 300; placeholderText: "Input beneath popup" }
        AudioProfileSelector {
            id: profile
            x: 16; y: 310; width: 300
            card: ({activeProfile:"long",profiles:[{name:"long",description:"A deliberately long audio profile description wrapping into a second line"},
                {name:"other",description:"Other profile"}]})
            audioService: mockAudio
        }
        QtObject { id: mockAudio; property bool profileBusy: false; function setProfile(card: var, name: string) {} }
        Flickable {
            id: scroller
            x: 16; y: 450; width: 300; height: 70
            clip: true; contentHeight: 150
            AudioSelector {
                id: device
                width: 300; compact: true
                options: [{name:"one",description:"One device"},{name:"two",description:"Two device"},{name:"three",description:"Three device"}]
                selectedName: "one"
            }
        }
        UI.InputField { id: outside; x: 340; y: 16; width: 160; placeholderText: "Synthetic outside input" }
        Test.TestCase { id: events; when: false }
        Test.TestResult { id: images }
        Timer {
            interval: 200; running: true
            onTriggered: {
                const closedHeight = combo.height
                const followingY = following.y
                combo.expanded = true
                root.check(combo.choicesView.activeFocus, "keyboard navigation works during the opening animation")
                events.keyClick(Qt.Key_Up)
                events.keyClick(Qt.Key_Down)
                events.wait(250)
                root.check(combo.popup.opened && combo.height === closedHeight && following.y === followingY,
                    "opening overlays content without changing control height or sibling placement")
                root.check(combo.choicesView.currentIndex === 2 && combo.choicesView.activeFocus,
                    "opening reveals and focuses the current selection")
                root.check(combo.popup.contentItem.Window.window === body.Window.window && combo.popup.popupType === QC.Popup.Item,
                    "dropdown stays in its owning window")
                const bounds = combo.contentBounds()
                const popupCorner = combo.popup.contentItem.mapToItem(bounds, 0, 0)
                root.check(popupCorner.x >= 0 && popupCorner.y >= 0 && popupCorner.x + combo.popup.contentItem.width <= bounds.width
                    && popupCorner.y + combo.popup.contentItem.height <= bounds.height,
                    "popup remains inside the host content and input bounds")
                if (root.nativeTest) root.check(body.QsWindow.window.WlrLayershell.namespace === "quickshell-private",
                    "native dropdown shares the private layer namespace")
                root.check((combo.popup.background as Rectangle).color.a === 1 && (combo.popup.background as Rectangle).border.width === 1,
                    "popup has a continuous opaque framed surface")
                if (Quickshell.env("SELECTION_TEST_PREVIEW")) {
                    const snapshot = images.grabImage(combo.popup.parent)
                    // QtTest snapshot methods are absent from its qmltypes.
                    // qmllint disable missing-property
                    snapshot.save(Quickshell.env("SELECTION_TEST_PREVIEW"))
                    // qmllint enable missing-property
                }
                events.keyClick(Qt.Key_Up)
                root.check(combo.choicesView.currentIndex === 0 && body.selection === "chosen", "navigation skips disabled options and does not apply")
                events.keyClick(Qt.Key_End)
                events.keyClick(Qt.Key_Return)
                events.wait(250)
                root.check(body.selection === "last" && body.commits === 1 && !combo.expanded, "Enter applies exactly one selection")
                combo.expanded = true
                events.wait(250)
                events.keyClick(Qt.Key_Home)
                events.keyClick(Qt.Key_Escape)
                events.wait(250)
                root.check(!combo.expanded && body.selection === "last" && body.commits === 1 && body.escapes === 0,
                    "Escape dismisses only the dropdown without applying")
                const comboToggle = events.findChild(combo, combo.toggleObjectName) as QC.Button
                root.check(comboToggle !== null && comboToggle.activeFocus, "Escape returns focus to the trigger")
                combo.expanded = true
                events.wait(250)
                combo.expanded = false
                events.mouseClick(following, 20, 15)
                root.check(following.activeFocus && body.commits === 1, "closing animation does not intercept clicks beneath it")
                events.wait(250)
                combo.expanded = true
                events.wait(250)
                events.mouseClick(outside, 20, 15)
                events.wait(250)
                root.check(!combo.expanded && outside.activeFocus, "outside click closes and focuses the clicked input")
                combo.expanded = true
                events.wait(250)
                const profileToggle = events.findChild(profile, profile.toggleObjectName) as QC.Button
                root.check(profileToggle !== null, "profile selector exposes its trigger")
                if (!profileToggle) { Qt.quit(); return }
                events.mouseClick(profileToggle, 20, 15)
                events.wait(250)
                root.check(!combo.expanded && profile.expanded && profile.choicesView.activeFocus,
                    "opening another selector closes the previous popup without stealing focus")
                profile.expanded = false
                events.wait(250)
                device.expanded = true
                events.wait(250)
                const controlTop = device.mapToItem(device.popup.parent, 0, 0).y
                root.check(device.popup.opened && device.popup.y < controlTop,
                    "near the bottom, audio dropdown opens above its clipped scroll container")
                root.check(device.popup.contentItem.parent !== scroller.contentItem && scroller.height === 70,
                    "scroll container clips neither dropdown nor changes height")
                scroller.flick(0, -300)
                events.wait(180)
                root.check(!device.expanded, "scrolling the anchor closes the popup")
                combo.expanded = true
                events.wait(250)
                combo.enabled = false
                events.wait(250)
                root.check(!combo.expanded && !combo.popup.visible, "disabling selector closes its popup")
                combo.enabled = true
                combo.options = Array.from({length:16}, (_,index) => ({name:"profile" + index,description:"Profile " + index}))
                body.selection = "profile0"
                combo.expanded = true
                events.wait(250)
                combo.choicesView.positionViewAtEnd()
                const scrolledY = combo.choicesView.contentY
                root.check(scrolledY > combo.choicesView.originY, "long profile list scrolls below the selected option")
                combo.options = combo.options.map(option => Object.assign({}, option))
                events.wait(100)
                root.check(Math.abs(combo.choicesView.contentY - scrolledY) < 1, "equivalent profile refresh preserves manual scrolling")
                combo.options = combo.options.map(option => Object.assign({},option,{description:option.description + " refreshed"}))
                events.wait(100)
                root.check(Math.abs(combo.choicesView.contentY - scrolledY) < 1, "updated profile labels preserve the browsing viewport")
                combo.expanded = false
                combo.expanded = true
                events.wait(250)
                root.check(combo.choicesView.currentIndex === 0 && combo.choicesView.contentY < scrolledY,
                    "reopening still reveals the selected profile")
                combo.expanded = false
                if (!root.failed) console.log("PASS: selection overlays preserve layout, private ownership, bounds, focus, disabled options, keyboard and outside-click behavior")
                Qt.quit()
            }
        }
    }
}
