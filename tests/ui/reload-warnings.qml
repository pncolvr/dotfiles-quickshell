import QtQml
import Quickshell
import "../../src/services"

Scope {
    id: root
    // The runner inserts the actual shell's root destruction handler here.
    // ROOT_DESTRUCTION_HANDLER
    PersistentProperties {
        id: state
        reloadableId: "tooltip-reload-warnings"
        property int generations: 0
    }
    QtObject {
        id: source
        property bool ownsTooltipWindow: true
    }
    Component { id: content; QtObject {} }
    Component.onCompleted: {
        TooltipService.openForKeyboard(0, content, source, false, null)
        if (!TooltipService.visible || !TooltipService.ownsTooltipWindow || TooltipService.content !== content) {
            console.error("RELOAD WARNINGS FAIL: active tooltip ownership")
            Qt.quit()
        }
    }
    Timer {
        interval: 80
        running: true
        onTriggered: {
            if (++state.generations < 20) Quickshell.reload(false)
            else {
                console.log("PASS: twenty tooltip generations release their owners without undefined bindings")
                Qt.quit()
            }
        }
    }
}
