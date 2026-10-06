pragma ComponentBehavior: Bound

import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/theme/ui" as UI
import "../../src/services"

Scope {
    QtObject { id: origin }
    Test.TestEvent { id: events }
    FloatingWindow {
        visible: true
        implicitWidth: 400
        implicitHeight: 80
        UI.SearchField { id: search; width: 360 }
    }
    IpcHandler {
        target: "tooltipsearchtest"
        function snapshot(): string {
            return JSON.stringify({visible: TooltipService.visible, paused: TooltipService.typingPaused,
                pinned: TooltipService.pinned, text: search.text, focused: search.activeFocus})
        }
        function begin(text: string): void {
            TooltipService.show(200, null, origin, false)
            TooltipService.hide()
            search.forceActiveFocus()
            search.text = text
            search.textEdited()
        }
        function type(text: string): void { search.text = text; search.textEdited() }
        function hover(hovered: bool): void { TooltipService.setPanelHovered(hovered) }
        function pin(): void { TooltipService.togglePin(200, null, origin, false) }
        function clear(): void {
            const button = search.children.find(child => child.objectName === "clearSearch") as UI.ActionButton
            button.clicked()
        }
        function pressEscape(): bool { return events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0) }
    }
}
