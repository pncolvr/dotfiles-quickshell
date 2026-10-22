pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../src/ui" as UI
import "../../src/ui/panels"
import "../../src/services"
import "../../src/theme"
import "../../src/modules/system/audio" as Audio

WorkerScope {
    id: root
    property string mode: "compact"
    readonly property bool privateCase: mode === "private"
    readonly property var activeHost: privateCase ? privateHost : publicHost
    readonly property var fixture: activeHost.loadedContent
    property int commits: 0
    property string chosen: ""
    QtObject {
        id: origin
        readonly property bool ownsTooltipWindow: root.privateCase
        readonly property bool tooltipKeyboardFocus: true
    }
    Test.TestResult { id: objects }
    TooltipWindow {
        id: publicHost
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-dropdown-check"
        exclusionMode: ExclusionMode.Ignore
        screen: Quickshell.screens[0]
    }
    PrivateTooltipWindow {
        id: privateHost
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        screen: Quickshell.screens[0]
        requestedVisible: root.privateCase && TooltipService.visible
        readonly property var loadedContent: privateLoader.item
        contentWidth: 380
        contentHeight: ((privateLoader.item as Item)?.implicitHeight ?? 0) + Theme.tooltipPaddingHeight * 2
        Loader {
            id: privateLoader
            active: privateHost.visible
            width: 340
            y: Theme.tooltipPaddingHeight
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: TooltipService.content
        }
    }
    component Fixture: Item {
        id: body
        implicitWidth: 340
        implicitHeight: root.mode === "mic" ? app.implicitHeight : generic.height
        width: implicitWidth
        height: implicitHeight
        readonly property UI.ComboSelector selector: root.mode === "mic"
            ? objects.findChild(app, "appDeviceSelector") as UI.ComboSelector : generic
        UI.ComboSelector {
            id: generic
            width: parent.width
            visible: root.mode !== "mic"
            compact: true
            searchable: root.mode === "searchable"
            selectedName: "first"
            options: [{name:"first", description:"First option"}, {name:"second", description:"Second option"}]
            onSelected: name => { root.chosen = name; root.commits++ }
        }
        QtObject {
            id: backend
            property bool routingBusy: false
            property var inputs: [{name:"first", description:"Headset microphone", ready:true},
                {name:"second", description:"Webcam microphone", ready:true}]
            property var outputs: []
            function deviceName(device: var): string { return device.description }
            function appMuted(app: var): bool { return false }
            function appVolume(app: var): real { return 0.5 }
            function moveApp(app: var, device: var, input: bool) { root.chosen = device.name; root.commits++ }
        }
        Audio.AudioAppRow {
            id: app
            width: parent.width
            visible: root.mode === "mic"
            input: true
            audioService: backend
            app: ({name:"Synthetic recording application", deviceName:"first", routable:true,
                nodes:[{ready:true, audio:{muted:false, volume:0.5}}]})
        }
    }
    Component { id: contents; Fixture {} }
    function target(item: Item, x: real, y: real): string {
        const point = item.mapToItem(activeHost.contentItem, x, y)
        return JSON.stringify({pid:Quickshell.processId, namespace:activeHost.WlrLayershell.namespace, x:point.x, y:point.y})
    }
    IpcHandler {
        target: "dropdowncheck"
        function begin(mode: string): void {
            TooltipService.dismiss()
            root.mode = mode
            root.chosen = ""
            TooltipService.show(Quickshell.screens[0].x + Quickshell.screens[0].width / 2,
                contents, origin, true, Quickshell.screens[0])
            TooltipService.setTriggerHovered(origin, true)
        }
        function leaveTrigger(): void { TooltipService.setTriggerHovered(origin, false); TooltipService.hide() }
        function dismiss(): void { TooltipService.dismiss() }
        function pointer(which: string): string {
            const combo = root.fixture.selector as UI.ComboSelector
            if (which === "toggle") return root.target(objects.findChild(combo, combo.toggleObjectName) as Item, 20, 15)
            if (which === "option") {
                const row = combo.choicesView.itemAtIndex(1)
                return root.target(row, row.width / 2, row.height / 2)
            }
            return root.target(root.activeHost.contentItem, root.activeHost.width - 10, root.activeHost.height - 10)
        }
        function snapshot(): string {
            const combo = root.fixture?.selector as UI.ComboSelector
            const toggle = combo ? objects.findChild(combo, combo.toggleObjectName) as QC.Button : null
            const row = combo?.choicesView.itemAtIndex(1) as UI.SelectableRow
            const rowTop = row?.mapToItem(root.activeHost.contentItem, 0, 0).y ?? -1
            const observer = objects.findChild(root.activeHost, "tooltipPointerHandler") as TooltipPointerHandler
            return JSON.stringify({visible:root.activeHost.visible, ready:!!toggle, settled:!root.activeHost.transitioning,
                expanded:combo?.expanded ?? false, opened:combo?.popup.opened ?? false,
                toggleHovered:toggle?.hovered ?? false, rowHovered:row?.pointerHovered ?? false,
                popupHovered:observer?.popupHovered ?? false, panelHeight:root.activeHost.contentHeight,
                rowOutside:rowTop >= root.activeHost.surfaceComponent.inputRect.height,
                commits:root.commits, chosen:root.chosen, namespace:root.activeHost.WlrLayershell.namespace,
                regions:root.activeHost.mask.regions[0]?.regions.length ?? 0})
        }
    }
}
