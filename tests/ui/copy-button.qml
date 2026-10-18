pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../src/ui" as UI
import "../../src/theme"
import "../../src/i18n"
import "../launcher" as Fixtures

Scope {
    id: root
    property var completion: null
    FloatingWindow {
        visible: true
        implicitWidth: 200
        implicitHeight: 80
        UI.CopyButton { id: button; feedbackDuration: 20; copyContext: "first" }
    }
    Fixtures.NativeFocusDriver {
        id: driver
        onFailed: message => { console.error("COPY BUTTON FAIL:", message); Qt.quit() }
        onCompleted: { console.log("PASS: shared copy success, failure, expiry, async completion, stale context, hiding and external confirmation"); Qt.quit() }
    }
    Component.onCompleted: {
        driver.add("failed copy", () => {
            button.copyAction = completed => completed(false)
            button.clicked()
            driver.check(!button.copied && button.glyph === Theme.copyIcon, "failure must not show success")
        })
        driver.add("successful copy", () => {
            button.copyAction = completed => completed(true)
            button.clicked()
            driver.check(button.copied && button.glyph === Theme.checkIcon && button.foreground.toString() === Theme.active.toString()
                && button.hint === Translations.text("common.status.copied"), "success matches TOTP feedback")
        })
        driver.waitFor("feedback expires", () => !button.copied)
        driver.add("asynchronous copy", () => {
            button.copyAction = completed => { root.completion = completed }
            button.clicked()
            driver.check(!button.copied, "pending copy must not show success")
            root.completion(true)
            driver.check(button.copied, "completion confirms success")
        })
        driver.add("changed copy context", () => {
            button.clicked()
            button.copyContext = "second"
            root.completion(true)
            driver.check(!button.copied, "late completion must not mark a different row")
        })
        driver.add("hidden button", () => {
            button.clicked()
            button.visible = false
            root.completion(true)
            button.visible = true
            driver.check(!button.copied, "hidden button must discard pending feedback")
        })
        driver.add("external TOTP confirmation", () => {
            button.externallyConfirmed = true
            driver.check(button.copied && button.glyph === Theme.checkIcon, "external confirmation uses shared visuals")
            button.externallyConfirmed = false
            driver.check(!button.copied && button.glyph === Theme.copyIcon, "external reset restores copy icon")
        })
        driver.running = true
    }
}
