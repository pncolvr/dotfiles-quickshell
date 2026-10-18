pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../src/ui" as UI
import "../launcher" as Fixtures

// Diagnostic only: synthetic values and mocked copy, no real clipboard access.
Scope {
    id: root
    property string scenario: "starting"
    property int clicks: 0
    property int buttonFocusChanges: 0
    property bool trackButtonFocus: false
    FloatingWindow {
        id: host
        visible: true
        implicitWidth: 640
        implicitHeight: 320
        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8
            QC.TextField { id: editable; objectName: "editableQtField"; width: 580; text: "Synthetic editable value" }
            QC.TextField { id: readOnly; objectName: "readonlyQtField"; width: 580; readOnly: true; text: "Synthetic readonly value" }
            UI.SecretField { id: secret; objectName: "readonlySecretField"; width: 580; readOnly: true; text: "SYNTHETIC_VALUE" }
            UI.TextArea { id: notes; objectName: "readonlyNotes"; width: 580; height: 60; readOnly: true; text: "Synthetic notes" }
            Row {
                spacing: 16
                QC.Button { id: plain; objectName: "plainQtButton"; text: "Plain Qt"; onClicked: root.clicks++ }
                UI.ActionButton { id: action; objectName: "sharedActionButton"; label: "Action"; onClicked: root.clicks++ }
                UI.CopyButton {
                    id: copy
                    objectName: "sharedCopyButton"
                    label: "Copy (mock)"
                    copyAction: completed => { root.clicks++; completed(true) }
                }
            }
        }
    }
    Connections { target: action; function onActiveFocusChanged() { if (root.trackButtonFocus) root.buttonFocusChanges++ } }
    Connections { target: copy; function onActiveFocusChanged() { if (root.trackButtonFocus) root.buttonFocusChanges++ } }
    function trace(stage) {
        const focused = host.contentItem.Window.window?.activeFocusItem
        console.log("TEXTINPUT TRACE", JSON.stringify({scenario, stage, active: host.contentItem.Window.active,
            field: focused?.objectName, focusReason: focused?.focusReason, clicks}))
    }
    Fixtures.NativeFocusDriver {
        id: driver
        onFailed: message => { root.trace("failed"); console.error("TEXTINPUT FAIL:", message); Qt.quit() }
        onCompleted: { console.log("PASS: textinput diagnostic completed; inspect warnings between scenario markers"); Qt.quit() }
    }
    function addScenario(source, button) {
        const name = source.objectName + " -> " + button.objectName
        const state = {clicks: 0}
        driver.add(name + " begin", () => {
            root.scenario = name
            root.trace("begin")
            source.forceActiveFocus(Qt.TabFocusReason)
        })
        driver.waitFor(name + " source focused", () => source.activeFocus, () => root.trace("source focused"))
        for (const stage of ["first click", "repeated click", "keyboard-to-mouse click"]) {
            if (stage === "keyboard-to-mouse click") {
                driver.add(name + " keyboard focus", () => button.forceActiveFocus(Qt.TabFocusReason))
                driver.waitFor(name + " button focused", () => button.activeFocus)
            }
            driver.add(name + " " + stage, () => {
                root.trace(stage + " before")
                state.clicks = root.clicks + 1
                root.buttonFocusChanges = 0
                root.trackButtonFocus = stage !== "first click"
                driver.click(button, button.width / 2, button.height / 2)
                root.trackButtonFocus = false
                driver.check(root.buttonFocusChanges === 0, "repeated clicks must not clear/restore button focus")
                root.trace(stage + " after")
            })
            driver.waitFor(name + " " + stage + " delivered", () => root.clicks === state.clicks)
        }
        driver.add(name + " end", () => root.trace("end"))
    }
    Component.onCompleted: {
        driver.add("request activation", () => host.contentItem.Window.window.requestActivate())
        driver.waitFor("native activation", () => host.contentItem.Window.active)
        for (const source of [editable, readOnly, secret, notes])
            for (const button of [plain, action, copy]) root.addScenario(source, button)
        driver.running = true
    }
}
