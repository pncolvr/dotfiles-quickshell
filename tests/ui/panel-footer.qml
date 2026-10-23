pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/ui" as UI
import "../../src/theme"
import "../../src/services"
import "../../src/modules/launcher" as Launcher
import "../launcher" as Fixtures

WorkerScope {
    id: root
    Test.TestCase { id: captures; when: false }
    function preview(name) {
        const folder = Quickshell.env("PANEL_FOOTER_PREVIEWS")
        if (folder) captures.grabImage(window.contentItem).save(folder + "/" + name + ".png")
    }
    QtObject { id: source; property string error: "" }
    FloatingWindow {
        id: window
        color: Theme.background
        visible: true
        implicitWidth: 900; implicitHeight: 800
        Item {
            id: frame
            width: 560; height: 180
            UI.PanelFooter {
                id: footer
                objectName: "testFooter"
                anchors.bottom: parent.bottom
                width: parent.width
                hints: "Ctrl+E: Edit · Esc: Close"
                message: source.error
            }
        }
        UI.ManagementView {
            id: manage
            y: 200; width: 800; height: 300
            entries: [{id:"one",title:"First"}]
            message: source.error
        }
        Launcher.PickerPanelBase {
            id: picker
            y: 510; width: 800; height: implicitHeight
        }
    }
    Fixtures.NativeFocusDriver {
        id: driver
        onFailed: message => { console.error("FOOTER FAIL:", message); Qt.quit() }
        onCompleted: { console.log("PASS: panel gutters center hints and transient feedback, preserve errors, restore hints and bound message duration"); Qt.quit() }
    }
    function manageFooter() { return driver.find(manage, "managementHints") }
    function pickerFooter() { return driver.find(picker, "pickerFooterHint") }
    Component.onCompleted: {
        driver.waitFor("catalog and controls", () => !!manageFooter() && !!pickerFooter() && footer.text.includes("Edit"))
        driver.add("normal gutter", () => {
            driver.check(footer.height === Theme.scrollbarGutter, "one-line hints fit the existing gutter")
            driver.check(footer.y + footer.height === frame.height, "footer ends at the panel bottom")
            driver.check(footer.horizontalAlignment === Text.AlignHCenter && footer.verticalAlignment === Text.AlignVCenter, "center both axes")
            driver.check(footer.messageDuration === 8000, "default eight-second feedback")
            root.preview("hints")
            footer.messageDuration = 60000
            driver.check(footer.effectiveMessageDuration === 10000, "feedback capped at ten seconds")
            footer.messageDuration = 180
            manageFooter().messageDuration = 180
            pickerFooter().messageDuration = 180
            source.error = "Literal <warning>\nMore detail"
            PickerService.error = "Picker error"
        })
        driver.waitFor("message replaces hints", () => footer.showingMessage && manageFooter().showingMessage && pickerFooter().showingMessage, () => {
            driver.check(footer.text === "Literal <warning> More detail" && footer.textFormat === Text.PlainText, "render plain single-line feedback")
            driver.check(!footer.text.includes("Ctrl+E") && Qt.colorEqual(footer.color,Theme.warning), "warning replaces hints")
            driver.check(footer.height === Theme.scrollbarGutter, "message keeps gutter geometry")
            root.preview("warning")
            driver.check(manageFooter().mapToItem(manage,0,manageFooter().height).y === manage.height, "Manage feedback is in the bottom gutter")
            driver.check(pickerFooter().mapToItem(picker,0,pickerFooter().height).y === picker.height, "picker feedback is in the bottom gutter")
        })
        driver.waitFor("expiry restores hints", () => !footer.showingMessage && !manageFooter().showingMessage && !pickerFooter().showingMessage, () => {
            driver.check(footer.text.includes("Ctrl+E") && source.error.length > 0 && PickerService.error === "Picker error", "expiry restores hints without clearing errors")
            driver.check(manageFooter().text.length > 0, "Manage hints return")
        })
        driver.add("hintless message", () => { footer.hintsEnabled = false; source.error = "New warning" })
        driver.waitFor("hintless feedback", () => footer.showingMessage && footer.text === "New warning")
        driver.waitFor("hintless expiry", () => !footer.showingMessage, () => driver.check(footer.text === "" && footer.height === Theme.scrollbarGutter, "no hints still retains the gutter"))
        driver.add("new warning", () => source.error = "Another warning")
        driver.waitFor("new warning shown", () => footer.showingMessage)
        driver.add("hide panel", () => frame.visible = false)
        driver.waitFor("hidden timer released", () => !footer.showingMessage)
        driver.add("reopen panel", () => frame.visible = true)
        driver.waitFor("retained error gets a fresh bounded display", () => footer.showingMessage)
        driver.add("clear error", () => { source.error = ""; PickerService.error = "" })
        driver.waitFor("cleared message", () => !footer.showingMessage)
        driver.running = true
    }
}
