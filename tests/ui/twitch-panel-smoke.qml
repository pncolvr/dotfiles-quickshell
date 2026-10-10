pragma ComponentBehavior: Bound

import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../src/bar"
import "../../src/modules/media"
import "../../src/modules/system/totp"
import "../../src/modules/system"
import "../../src/services"
import "../../src/theme"
import "../../src/theme/ui" as UI

Scope {
    id: root
    property int volumeLoads: 0
    property bool badgeVisible: false
    Test.TestResult { id: objects }
    Test.TestEvent { id: events }
    // Quickshell selects the native PanelWindow backend at runtime.
    // qmllint disable uncreatable-type
    PanelWindow {
        id: testBar
        WlrLayershell.layer: WlrLayer.Overlay
        // qmllint enable uncreatable-type
        screen: Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0]
        anchors { top: true; left: true; right: true }
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        visible: true
        implicitWidth: 800
        implicitHeight: 30
        Row {
            anchors.right: parent.right
            Twitch { id: twitch; moduleName: "twitch"; moduleFocusSearch: true }
            Totp { id: totp; moduleName: "totp"; moduleFocusSearch: true; window: testBar }
            Volume { id: volume; moduleName: "volume" }
            Rectangle { width: root.badgeVisible ? 120 : 0; height: 30; visible: root.badgeVisible }
            Tray { id: tray; moduleName: "tray"; window: testBar }
            UI.TooltipArea { moduleName: "hidden"; visible: false; tooltip: Component { Item {} } }
        }
    }
    // The fixture bar reserves no desktop space; place its panels below it.
    TooltipWindow { id: window; screen: testBar.screen; margins.top: 30 }
    Connections {
        target: window
        function onLoadedContentChanged() {
            if (window.loadedContent && TooltipService.source === volume) root.volumeLoads++
        }
    }
    readonly property bool observedMuted: AudioService.muted
    readonly property real observedVolume: AudioService.volume
    TotpWindow { id: totpWindow; margins.top: 30 }
    readonly property TotpTooltip totpPanel: totpWindow.loadedContent as TotpTooltip
    readonly property UI.SearchField totpSearch: root.totpPanel
        ? objects.findChild(root.totpPanel, "totpSearchField") as UI.SearchField : null
    onTotpSearchChanged: if (totpSearch) totpSearch.readOnly = true
    readonly property TwitchTooltip panel: window.loadedContent as TwitchTooltip
    readonly property UI.SearchField search: root.panel
        ? objects.findChild(root.panel, "twitchSearchField") as UI.SearchField : null
    // Keep real desktop typing from changing the fixture between assertions.
    onSearchChanged: if (search) search.readOnly = true
    IpcHandler {
        target: "twitchpaneltest"
        function snapshot(): string {
            const iconCenter = twitch.mapToGlobal(twitch.width / 2, twitch.height / 2)
            const pointerTarget = {x: iconCenter.x, y: iconCenter.y}
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
        function snapshotTotp(): string {
            const pos = totp.mapToGlobal(totp.width / 2, totp.height / 2)
            return JSON.stringify({visible: totpWindow.visible, focused: root.totpSearch?.activeFocus ?? false,
                keyboard: TooltipService.keyboardActive, source: TooltipService.source === totp,
                screen: TooltipService.screen === totp.tooltipScreen,
                windowActive: totpWindow.nativeWindow?.active ?? false,
                onDemand: totpWindow.WlrLayershell.keyboardFocus === WlrKeyboardFocus.OnDemand,
                pinned: TooltipService.pinned, adding: root.totpPanel?.adding ?? false,
                text: root.totpSearch?.text ?? "", pointerTarget: {x: pos.x, y: pos.y}})
        }
        function typeTotp(text: string): void {
            if (!root.totpSearch) return
            root.totpSearch.readOnly = false
            root.totpSearch.clear()
            for (const character of text) events.keyClickChar(character, Qt.NoModifier, 0)
            root.totpSearch.readOnly = true
        }
        function beginTotpAdd(): void { if (root.totpPanel) root.totpPanel.adding = true }
        function snapshotVolume(): string {
            const pos = volume.mapToGlobal(volume.width / 2, volume.height / 2)
            return JSON.stringify({visible: window.visible, source: TooltipService.source === volume,
                keyboard: TooltipService.keyboardActive, pinned: TooltipService.pinned,
                muted: root.observedMuted, volume: root.observedVolume, loads: root.volumeLoads,
                hovered: volume.tooltipHovered, mouseAreaHovered: volume.containsMouse,
                badge: root.badgeVisible, pointerTarget: {x: pos.x, y: pos.y}})
        }
        function showBadge(): void { root.badgeVisible = true }
        function openAfterBadge(): bool { root.badgeVisible = false; return BarModuleService.open("volume") }
        function snapshotTray(): string {
            const pos = tray.mapToGlobal(0, 0)
            return JSON.stringify({expanded: tray.expanded, x: pos.x, y: pos.y, width: tray.width, height: tray.height})
        }
        function hoverVolumeEdge(): bool { return events.mouseMove(volume, volume.width / 2, 1, 0, Qt.NoButton, Qt.NoModifier) }
        function leaveBar(): bool { return events.mouseMove(testBar.contentItem, 1, 15, 0, Qt.NoButton, Qt.NoModifier) }
        function hoverTrayEdge(): bool { return events.mouseMove(tray, 1, 1, 0, Qt.NoButton, Qt.NoModifier) }
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
