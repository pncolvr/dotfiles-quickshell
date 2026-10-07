pragma ComponentBehavior: Bound

import QtQuick
import QtTest as Test
import Quickshell
import "../../src/modules/launcher"
import "../../src/services"

Scope {
    id: root
    property int step: 0
    Test.TestEvent { id: events }
    PickerWindow { id: window }
    Timer {
        running: true
        repeat: true
        interval: 400
        onTriggered: {
            if (root.step === 0) {
                PickerService.apps()
            } else if (root.step === 1) {
                if (PickerService.items.length === 0) {
                    console.error("PICKER FAIL: native application index")
                    Qt.quit()
                    return
                }
                PickerService.begin("menu", "Quickshell picker preview")
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
                    PickerService.mode = "clipboard"
                    PickerService.destination = "0x123"
                    PickerService.items = [{id:"0",title:"Short copied text",result:{}},
                        {id:"1",title:"A longer copied paragraph, previewed over two lines so the contents remain readable while each row stays compact.",result:{}},
                        {id:"2",title:"image/png",subtitle:"24 KiB",result:{}}]
                }
                PickerService.show()
            } else if (root.step === 2) {
                if (!window.visible || window.width > window.screen.width || window.height > window.screen.height) {
                    console.error("PICKER FAIL: native window geometry")
                    Qt.quit()
                    return
                }
                window.previewItem.grabToImage(result => {
                    result.saveToFile(Quickshell.env("PICKER_TEST_SCREENSHOT"))
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                    console.log(PickerService.visible ? "PICKER FAIL: native Escape" : "PASS: native picker geometry, focus and Escape")
                    Qt.quit()
                })
            } else if (root.step > 10) { console.error("PICKER FAIL: native screenshot timeout"); Qt.quit() }
            root.step++
        }
    }
}
