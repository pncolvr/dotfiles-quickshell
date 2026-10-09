pragma ComponentBehavior: Bound

import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../src/bar"
import "../../src/modules/media"
import "../../src/services"
import "../../src/theme"
import "../../src/theme/ui" as UI

Scope {
    id: root
    Test.TestResult { id: objects }
    Test.TestEvent { id: events }
    // Quickshell selects the native PanelWindow backend at runtime.
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        screen: Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0]
        anchors { top: true; right: true }
        exclusiveZone: 0
        visible: true
        implicitWidth: 800
        implicitHeight: 30
        Twitch { id: twitch; anchors.right: parent.right }
    }
    TooltipWindow { id: window; screen: twitch.tooltipScreen }
    readonly property TwitchTooltip panel: window.loadedContent as TwitchTooltip
    readonly property UI.SearchField search: root.panel
        ? objects.findChild(root.panel, "twitchSearchField") as UI.SearchField : null
    // Keep real desktop typing from changing the fixture between assertions.
    onSearchChanged: if (search) search.readOnly = true
    IpcHandler {
        target: "twitchpaneltest"
        function snapshot(): string {
            const iconBottom = twitch.mapToGlobal(twitch.width / 2, twitch.height)
            const pointerTarget = {x: iconBottom.x, y: iconBottom.y + Theme.tooltipPaddingHeight}
            return JSON.stringify({visible: window.visible, pinned: TooltipService.pinned,
                keyboard: TooltipService.keyboardActive, source: TooltipService.source === twitch,
                screen: TooltipService.screen === twitch.tooltipScreen,
                focused: root.search?.activeFocus ?? false, adding: root.panel?.adding ?? false,
                windowActive: window.nativeWindow?.active ?? false,
                onDemand: window.WlrLayershell.keyboardFocus === WlrKeyboardFocus.OnDemand,
                requestingFocus: window.requestingKeyboardFocus,
                text: root.search?.text ?? "", pointerTarget})
        }
        function beginAdd(): void { if (root.panel) root.panel.adding = true }
        function type(text: string): void {
            if (!root.search) return
            root.search.readOnly = false
            root.search.clear()
            for (const character of text) events.keyClickChar(character, Qt.NoModifier, 0)
            root.search.readOnly = true
        }
        function pressEscape(): bool { return events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0) }
        function dismiss(): void { TooltipService.dismiss() }
        function clickIcon(): bool {
            return events.mouseClick(twitch, twitch.width / 2, twitch.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
        }
    }
}
