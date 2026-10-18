pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../src/modules/launcher"
import "../../src/services"

Scope {
    id: root
    property bool screenshotComplete: false
    property bool screenshotSaved: false
    PickerWindow { id: window }

    function focusState() {
        const handler = driver.find(window.contentItem, "windowFocusHandler")
        return JSON.stringify({visible: PickerService.visible, hostVisible: window.visible,
            active: window.windowActive, field: window.contentItem.Window.window?.activeFocusItem?.objectName,
            ready: handler?.ready, requesting: handler?.requestingKeyboardFocus,
            settled: handler?.activationSettled, retaining: handler?.retainingNativeFocus})
    }
    function inputReady() {
        return window.visible && window.windowActive
            && driver.find(window.panel, "pickerSearch")?.activeFocus
    }
    function openPreview() {
        PickerService.begin(PickerService.Mode.Menu, "Quickshell picker preview")
        PickerService.items = [{id:"0",title:"Applications",subtitle:"Native desktop entries",result:"apps"},
            {id:"1",title:"Clipboard",subtitle:"Text and image history",result:"clipboard"},
            {id:"2",title:"Projects",subtitle:"Existing Bash providers",result:"projects"}]
        const preview = Quickshell.env("PICKER_TEST_PREVIEW")
        if (preview === "apps") {
            PickerService.apps()
        } else if (preview === "power") {
            PickerService.layout = "grid"
            PickerService.items = [{id:"0",title:"Reboot",glyph:"",result:"Reboot"},
                {id:"1",title:"Lock",glyph:"",result:"Lock"},
                {id:"2",title:"Logout",glyph:"",result:"Logout"},
                {id:"3",title:"Shutdown",glyph:"",result:"Shutdown"},
                {id:"4",title:"Bios",glyph:"",result:"Bios"}]
        } else if (preview === "browser") {
            PickerService.multiple = true
            PickerService.acceptLabel = "Open links"
            PickerService.items = [{id:"0",title:"Documentation",result:"https://example.com/docs"},
                {id:"1",title:"Projects",result:"https://example.com/projects"},
                {id:"2",title:"Bookmarks",result:"https://example.com/bookmarks"}]
            PickerService.selectedIds = ["0", "2"]
        } else if (preview === "clipboard") {
            PickerService.mode = PickerService.Mode.Clipboard
            PickerService.destination = "0x123"
            PickerService.items = [{id:"0",title:"Short copied text",result:{}},
                {id:"1",title:"A longer copied paragraph, previewed over two lines so the contents remain readable while each row stays compact.",result:{}},
                {id:"2",title:"image/png",subtitle:"24 KiB",result:{}}]
        }
        PickerService.show()
    }
    NativeFocusDriver {
        id: driver
        onFailed: message => {
            console.error("PICKER FAIL:", message, root.focusState())
            PickerService.close()
            Qt.quit()
        }
        onCompleted: {
            console.log("PASS: native picker geometry, focus and Escape")
            Qt.quit()
        }
    }
    Component.onCompleted: {
        driver.add("open applications", () => PickerService.apps())
        driver.waitFor("native application index and focus", () => PickerService.items.length > 0 && root.inputReady())
        driver.add("open preview", () => root.openPreview())
        driver.waitFor("preview geometry and focus", () => root.inputReady() && !window.transitioning, () => {
            const screen = window.geometryScreen
            driver.check(!!screen && window.width > 0 && window.height > 0
                && window.width <= screen.width && window.height <= screen.height,
                "native window geometry")
            driver.check(window.panel.grabToImage(result => {
                root.screenshotSaved = result.saveToFile(Quickshell.env("PICKER_TEST_SCREENSHOT"))
                root.screenshotComplete = true
            }), "native screenshot request")
        })
        driver.waitFor("native screenshot", () => root.screenshotComplete, () => {
            driver.check(root.screenshotSaved, "save native screenshot")
        })
        driver.waitFor("Escape delivery", () => root.inputReady(), () => driver.key(Qt.Key_Escape))
        driver.waitFor("Escape closes picker", () => !PickerService.visible)
        driver.waitFor("native window closes", () => !window.visible)
        driver.running = true
    }
}
