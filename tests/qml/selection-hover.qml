pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../src/ui/panels"
import "../../src/services"
import "../../src/theme"
import "../../src/ui" as UI
import "../../src/modules/system/audio"

Scope {
    id: root
    property string mode: "volume"
    property bool above: true
    readonly property bool privateCase: mode === "private-folder"
    readonly property var activeHost: privateCase ? privateHost : publicHost
    readonly property Item panel: activeHost.loadedContent as Item
    property int writes: 0
    property var cursorControl: null
    property int cursorLeaves: 0
    function cursorHint(): QC.ToolTip {
        for (const object of cursorControl?.data ?? [])
            if (object instanceof QC.ToolTip) return object
        return null
    }
    QtObject {
        id: origin
        readonly property bool tooltipKeyboardFocus: true
        readonly property bool ownsTooltipWindow: root.privateCase
    }
    function selector(): UI.ComboSelector { return (root.panel as Fixture)?.selector ?? null }
    function offset(host: var) { host.margins.top = Theme.barHeight + 10 }
    TooltipWindow {
        id: publicHost
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        screen: Quickshell.screens[0]
        Component.onCompleted: root.offset(publicHost)
    }
    PrivateTooltipWindow {
        id: privateHost
        exclusionMode: ExclusionMode.Ignore
        screen: Quickshell.screens[0]
        requestedVisible: root.privateCase && TooltipService.visible
        readonly property var loadedContent: privateLoader.item
        contentWidth: 680
        contentHeight: 420
        WlrLayershell.layer: WlrLayer.Overlay
        Component.onCompleted: root.offset(privateHost)
        Loader { id: privateLoader; active: privateHost.visible; width: 640; height: 400; anchors.centerIn: parent; sourceComponent: TooltipService.content }
    }
    component Fixture: Item {
        id: body
        implicitWidth: 640
        implicitHeight: 400
        width: implicitWidth
        height: implicitHeight
        readonly property UI.ComboSelector selector: app.visible
            ? objects.findChild(app, "appDeviceSelector") as UI.ComboSelector : profile.visible ? profile : generic
        QtObject {
            id: backend
            property bool routingBusy: false
            property bool profileBusy: false
            property var outputs: [{name:"headphones",description:"Headphones",ready:true},
                {name:"speakers",description:"Speakers",ready:true}, {name:"surround",description:"Virtual Surround 5.1",ready:true}]
            property var inputs: [{name:"first",description:"First microphone",ready:true},
                {name:"monitor",description:"Monitor microphone",ready:true}, {name:"virtual",description:"Virtual microphone",ready:true}]
            function deviceName(device: var): string { return device.description }
            function appMuted(app: var): bool { return false }
            function appVolume(app: var): real { return 0.5 }
            function moveApp(app: var, device: var, input: bool) { root.writes++ }
            function setProfile(card: var, name: string) { root.writes++ }
        }
        UI.Text { x:20; y:12; text: root.mode === "mic" ? "Microphone · Apps" : root.mode === "volume" ? "Volume · Apps" : root.mode }
        UI.ActionButton {
            id: topAction
            objectName: "cursorTopButton"
            x:560; y:0
            glyph: Theme.refreshIcon
            hint: "Top action hint"
            onHoveredChanged: if (root.cursorControl === topAction && !hovered) root.cursorLeaves++
        }
        UI.ActionButton {
            id: lowerAction
            objectName: "cursorLowerButton"
            x:560; y:180
            glyph: Theme.lockIcon
            hint: "Lower action hint"
            onHoveredChanged: if (root.cursorControl === lowerAction && !hovered) root.cursorLeaves++
        }
        AudioAppRow {
            id: app
            x:20; y:root.above ? 280 : 40; width:600
            visible: root.mode === "volume" || root.mode === "mic"
            input: root.mode === "mic"
            audioService: backend
            app: ({name:"Synthetic application", deviceName:root.mode === "mic" ? "monitor" : "headphones",routable:true,
                nodes:[{ready:true,audio:{muted:false,volume:0.5}}]})
        }
        AudioProfileSelector {
            id: profile
            x:20; y:root.above ? 320 : 40; width:600
            visible: root.mode === "profile"
            audioService: backend
            card: ({activeProfile:"stereo",profiles:[{name:"stereo",description:"Stereo"},
                {name:"surround",description:"Virtual Surround 5.1"}, {name:"duplex",description:"Duplex"}]})
        }
        UI.ComboSelector {
            id: generic
            x:20; y:root.above ? 320 : 40; width:300; compact:true
            visible: !app.visible && !profile.visible
            selectedName: "first"
            options: root.mode === "type" ? [{name:"first",description:"Logins"},{name:"second",description:"Notes"},{name:"third",description:"SSH keys"}]
                : [{name:"first",description:"All folders"},{name:"second",description:"Personal"},{name:"third",description:"Work"}]
            onSelected: name => root.writes++
        }
    }
    Component { id: volumeFixture; Fixture {} }
    Component { id: microphoneFixture; Fixture {} }
    Component { id: profileFixture; Fixture {} }
    Component { id: folderFixture; Fixture {} }
    Component { id: typeFixture; Fixture {} }
    Component { id: privateFixture; Fixture {} }
    Test.TestResult { id: objects }
    Test.TestEvent { id: events }
    function pointerTarget(item: Item, x: real, y: real): string {
        // Layer-shell global positioning is compositor-owned. The shell driver
        // adds the actual layer origin to these surface-local coordinates.
        const point = item.mapToItem(root.activeHost.contentItem, x, y)
        return JSON.stringify({x:point.x,y:point.y,pid:Quickshell.processId,
            namespace:root.activeHost.WlrLayershell.namespace})
    }
    IpcHandler {
        target: "selectionhover"
        function begin(mode: string, above: bool): void {
            root.cursorControl = null
            root.cursorLeaves = 0
            TooltipService.dismiss()
            root.mode = mode
            root.above = above
            const content = ({volume:volumeFixture,mic:microphoneFixture,profile:profileFixture,folder:folderFixture,type:typeFixture,"private-folder":privateFixture})[mode]
            TooltipService.show(Quickshell.screens[0].x + Quickshell.screens[0].width / 2,
                content, origin, true, Quickshell.screens[0])
            TooltipService.setTriggerHovered(origin, true)
        }
        function snapshot(): string {
            const selector = root.selector()
            const observer = objects.findChild(root.activeHost,"tooltipPointerHandler") as TooltipPointerHandler
            const toggle = selector ? objects.findChild(selector, selector.toggleObjectName) as QC.Button : null
            const rowHover = selector?.options.map((value,index)=>(selector.choicesView.itemAtIndex(index) as QC.ItemDelegate)?.hovered) ?? []
            return JSON.stringify({visible:root.activeHost.visible, settled:!root.activeHost.transitioning, expanded:selector?.expanded ?? false,
                popupVisible:selector?.popup.visible ?? false,popupOpened:selector?.popup.opened ?? false,
                writes:root.writes,hovered:observer?.hovered ?? false,
                popupHovered:observer?.popupHovered ?? false,
                cursorHovered:root.cursorControl?.hovered ?? false,cursorLeaves:root.cursorLeaves,
                cursorHintReady:!!root.cursorHint(),cursorHintOpened:root.cursorHint()?.opened ?? false,
                pinned:TooltipService.pinned,paused:TooltipService.interactionHeld,
                sameOverlay:!!selector && selector.popup.contentItem.parent?.parent === observer?.overlayItem,
                rowsReady:rowHover.length === 3 && rowHover.every(value => value !== undefined),rowHover,
                private:root.privateCase,namespace:root.privateCase ? privateHost.WlrLayershell.namespace : publicHost.WlrLayershell.namespace,
                toggleReady:!!toggle,toggleHovered:toggle?.hovered ?? false,
                opensAbove:!!selector?.expanded && selector.popup.y < selector.mapToItem(selector.popup.parent,0,0).y})
        }
        function geometry(): string {
            const selector = root.selector()
            if (!selector) return JSON.stringify({unloaded:true})
            const rect = item => {
                if (!item) return null
                const point = item.mapToItem(root.activeHost.contentItem, 0, 0)
                return {x:point.x,y:point.y,width:item.width,height:item.height}
            }
            return JSON.stringify({surface:{width:root.activeHost.width,height:root.activeHost.height},
                toggle:rect(selector),popup:rect(selector.popup.contentItem),
                rows:selector.options.map((value,index) => rect(selector.choicesView.itemAtIndex(index)))})
        }
        function syncPointer(target: string): void {
            // A compositor warp positions the real cursor; the click/move stream
            // injected by QtTest must agree with it for stationary hover checks.
            const point = JSON.parse(target)
            events.mouseMove(root.activeHost.contentItem,point.x,point.y,0,Qt.NoButton,Qt.NoModifier)
        }
        function hoverToggle(): string {
            const selector = root.selector()
            const toggle = objects.findChild(selector,selector.toggleObjectName) as QC.Button
            return root.pointerTarget(toggle,toggle.width/2,toggle.height/2)
        }
        function hoverAction(lower: bool, reset: bool): string {
            root.cursorControl = objects.findChild(root.panel,lower ? "cursorLowerButton" : "cursorTopButton") as QC.Button
            if (reset) root.cursorLeaves = 0
            return root.pointerTarget(root.cursorControl,root.cursorControl.width/2 + (reset ? 0 : 1),root.cursorControl.height/2)
        }
        function hover(index: int): string {
            const row = root.selector().choicesView.itemAtIndex(index) as QC.ItemDelegate
            return root.pointerTarget(row,row.width/2,row.height/2)
        }
        function leave(): string {
            return root.pointerTarget(root.activeHost.contentItem,0,root.activeHost.contentItem.height - 1)
        }
        function leaveTrigger(): void { TooltipService.setTriggerHovered(origin, false) }
        function open(): void {
            const selector = root.selector()
            const toggle = objects.findChild(selector,selector.toggleObjectName) as QC.Button
            events.mouseClick(toggle,toggle.width/2,toggle.height/2,Qt.LeftButton,Qt.NoModifier,0)
        }
    }
}
