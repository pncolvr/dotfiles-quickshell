pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/config"
import "../../src/services"
import "../../src/theme"
import "../../src/ui" as UI
import "../../src/modules/launcher"

Scope {
    id: root
    property int step: 0
    property int ticks: 0
    property bool failed: false
    property int clipboardTasks: 0
    property real imagePreviewCenter: 0
    Test.TestCase { id: events; when: false }
    Connections {
        target: ClipboardService
        function onPendingTasksChanged() { if (ClipboardService.pendingTasks > 0) root.clipboardTasks++ }
    }
    readonly property var preview: previewSurface
    readonly property var panel: mainPanel.panel
    readonly property var settings: Config
    readonly property var audio: AudioService
    property var geometryScreen: ({width:800,height:600})
    QtObject {
        id: geometryHost
        property var requestedScreen: root.geometryScreen
        property bool requestedVisible: false
        property real contentHeight: Math.min(200, root.geometryScreen.height * Theme.pickerPreviewListHeightRatio)
        property real layoutContentHeight: contentHeight
        property real shadowBottomPadding: Theme.tooltipShadowBlurRadius + Math.max(0,Theme.tooltipShadowVerticalOffset)
    }
    PickerPreviewSurface {
        id: geometrySurface
        host: geometryHost; picker: PickerService; previewPanel: null
        width: root.geometryScreen.width
        height: root.geometryScreen.height - Theme.barHeight
    }
    QtObject {
        id: popup
        property var requestedScreen: Quickshell.screens[0]
        property bool requestedVisible: PickerService.visible
        property real contentHeight: mainPanel.height
        property real layoutContentHeight: contentHeight
        property real shadowBottomPadding: 0
        property real contentWidth: mainPanel.width
        property real contentX: mainPanel.x
        property real width: listHost.width
        property Item contentItem: listHost.contentItem
    }
    FloatingWindow {
        id: listHost
        visible: true
        implicitWidth: popup.requestedScreen.width
        implicitHeight: popup.requestedScreen.height - Theme.barHeight
        PickerPanel {
            id: mainPanel
            x: (listHost.width - width) / 2
            width: Math.min(implicitWidth,Math.max(0,listHost.width - Theme.tooltipRadius * 2 - Theme.tooltipPaddingWidth * 2))
            height: Math.min(implicitHeight,listHost.height * (floatingPreviewRequested ? Theme.pickerPreviewListHeightRatio : 0.75))
        }
    }
    FloatingWindow {
        visible: previewSurface.presented
        implicitWidth: listHost.width
        implicitHeight: listHost.height
        PickerPreviewSurface {
            id: previewSurface
            anchors.fill: parent
            visible: presented
            host: popup
            picker: PickerService
            previewPanel: mainPanel
        }
    }
    function check(ok, message) { if (!ok) { failed = true; console.error("FLOATING FAIL:",step,message) } }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const found = find(child,name); if (found) return found }
        return null
    }
    function wallpaper() {
        PickerService.promptMenu("Fixture", Array.from({length:8}, (_,index) => ({
            title:"Image " + index,
            image:"file://" + Quickshell.shellPath(index % 2 ? "portrait.png" : "landscape.png"),
            result:String(index)
        })), () => {}, "list", {previewImages:true})
    }
    function screenBounds() {
        for (const [width,height] of [[320,240],[640,480],[800,600],[1366,768],[1920,1080],[2560,1440],[3840,2160],[1080,1920]]) {
            root.geometryScreen = {width,height}
            if (geometrySurface.previewHeight > 0) root.check(Math.abs(
                geometrySurface.previewTop - geometryHost.contentHeight
                - (height - Theme.barHeight - geometrySurface.previewTop - geometrySurface.previewHeight)) < 1,
                "matching top and bottom preview margins " + width + "x" + height)
            root.check(geometrySurface.previewWidth >= 0 && geometrySurface.previewHeight >= 0,"nonnegative geometry")
            root.check(geometrySurface.previewWidth + geometrySurface.horizontalInset * 2 <= width,"horizontal shadow fits " + width)
            if (geometrySurface.previewHeight > 0) root.check(geometrySurface.previewTop + geometrySurface.previewHeight
                + geometrySurface.shadowBottom + Theme.barHeight <= height,"bottom shadow fits " + height)
        }
    }
    function windows() {
        PickerService.begin(PickerService.Mode.Windows,"Windows")
        PickerService.layout = "switcher"
        PickerService.items = [{id:"window",title:"Fixture",client:{address:"",class:"fixture"}}]
        PickerService.show()
    }
    function layout() {
        root.check(popup.contentWidth === Math.min(Theme.pickerWidth,
            Math.max(0,popup.width - Theme.tooltipRadius * 2 - Theme.tooltipPaddingWidth * 2)), "list retains standard bounded width")
        root.check(Math.abs(popup.contentX - (popup.width - popup.contentWidth) / 2) < 1, "list retains standard centered anchor")
        root.check(preview.Window.window !== mainPanel.Window.window && preview.previewWidth > popup.contentWidth, "preview is a separate wider window")
        root.check(Math.abs(preview.previewTop - popup.contentHeight
            - (preview.requestedScreen.height - Theme.barHeight - preview.previewTop - preview.previewHeight)) < 1,
            "visible gap above preview matches screen margin below")
        root.check(preview.previewTop > popup.contentHeight, "preview starts below the list and shadow")
        root.check(preview.previewTop + preview.previewHeight + Theme.barHeight <= preview.requestedScreen.height, "preview fits the screen vertically")
        root.check(preview.previewWidth <= preview.requestedScreen.width - Theme.tooltipPaddingWidth * 2, "preview fits the screen horizontally")
        root.check(find(popup.contentItem,"clipboardPreviewPane") === null, "list contains no embedded preview")
    }
    Timer {
        id: driver
        interval: 40; running: true; repeat: true
        onTriggered: {
            if (root.failed || ++root.ticks > 300) { console.error("FLOATING FAIL: stopped at",root.step); Qt.quit(); return }
            if (!DbService.ready) return
            switch (root.step) {
            case 0:
                root.wallpaper(); root.step++; break
            case 1: {
                if (!root.preview.visible || root.preview.transitioning) return
                root.layout()
                root.check(root.panel.previewEnabled,"wallpaper alone defaults enabled")
                root.check(root.panel.maximumListRows === 4 && PickerService.items.length === 8,"preview caps rows while retaining all entries")
                const list = root.find(mainPanel,"pickerList") as UI.PickerList
                root.check(list.height <= root.panel.measuredRowHeight * 4 + Theme.controlSpacing * 3 + 1,"at most four rows are visible")
                const image = root.find(root.preview,"clipboardLargeImage") as UI.ScaledImage
                if (!image || image.status !== Image.Ready) return
                if (root.preview.transitioning) return
                const card = root.find(root.preview,"floatingPickerPreview")
                root.check(card.height <= image.paintedHeight + (root.preview.verticalPadding + Theme.controlSpacing) * 2 + 2,
                    "landscape preview removes vertical letterboxing")
                root.check(root.preview.horizontalPadding > root.preview.verticalPadding,"side padding exceeds vertical padding")
                root.check(image.mipmap && image.smooth && image.fillMode === Image.PreserveAspectFit,"floating image reuses shared renderer")
                root.imagePreviewCenter = card.y + card.height / 2
                PickerService.move(1); root.step++; break
            }
            case 2: {
                const card = root.find(root.preview,"floatingPickerPreview")
                root.check(Math.abs(card.y + card.height / 2 - root.imagePreviewCenter) < 1,
                    "preview center stays fixed while landscape changes to portrait")
                const image = root.find(root.preview,"clipboardLargeImage") as UI.ScaledImage
                if (!image || image.status !== Image.Ready || !image.source.toString().endsWith("portrait.png")) return
                root.layout()
                root.check(!root.panel.previewShortcut && !root.panel.footerHint.includes(UI.Keybinds.sequence("preview")),"wallpaper has no preview toggle or hint")
                driver.stop()
                listHost.contentItem.Window.window.requestActivate()
                events.wait(30)
                root.panel.focusSearch()
                events.keyClick(Qt.Key_I, Qt.ControlModifier | Qt.ShiftModifier)
                root.check(root.panel.previewEnabled,"preview shortcut cannot hide wallpaper")
                const beforeCopy = root.clipboardTasks
                events.keyClick(Qt.Key_C, Qt.ControlModifier)
                root.check(root.clipboardTasks > beforeCopy,"Ctrl+C dispatches image copy from search focus")
                root.step++; driver.start(); break
            }
            case 3:
                if (ClipboardService.pendingTasks) return
                root.check(PickerService.visible && root.panel.previewEnabled && root.preview.requestedVisible,"copy keeps wallpaper list and preview open")
                root.check(!ClipboardService.error,"image copy succeeds")
                PickerService.close(); root.windows(); root.step++; break
            case 4:
                if (root.panel?.previewKind !== "windows") return
                root.check(!root.panel.previewEnabled && !root.preview.requestedVisible,"window preview defaults off")
                root.panel.previewEnabled = true; root.step++; break
            case 5:
                if (!root.preview.visible || root.preview.transitioning) return
                root.layout()
                root.audio.screencastActive = true
                root.panel.previewEnabled = false
                root.check(!root.preview.visible && !root.preview.transitioning,"sharing closes without decorative motion")
                root.panel.previewEnabled = true
                root.check(root.preview.visible && !root.preview.transitioning,"sharing still permits a static preview")
                PickerService.close(); root.audio.screencastActive = false
                root.settings.pickerPreviewEnabled = true
                root.settings.pickerPreviewDefaults = {wallpaper:false,windows:null,clipboard:null}
                root.wallpaper(); root.step++; break
            case 6:
                if (root.panel?.previewKind !== "wallpaper") return
                root.check(root.panel.previewEnabled && !root.panel.previewShortcut,"wallpaper always previews even with an obsolete false override")
                PickerService.close(); root.windows(); root.step++; break
            case 7:
                if (root.panel?.previewKind !== "windows") return
                root.check(root.panel.previewEnabled,"window preview inherits global true")
                PickerService.close()
                root.check(ClipboardRepository.add({id:"a".repeat(64),mime:"image/png",kind:"image",bytes:100,text:""}) !== null,"seed clipboard image")
                PickerService.begin(PickerService.Mode.Clipboard,"Clipboard")
                PickerService.show(); root.step++; break
            case 8:
                if (PickerService.searchPending || !PickerService.currentItem) return
                root.check(root.panel.previewEnabled && root.panel.compactImageRows,"clipboard inherits global true with compact image rows")
                root.settings.pickerPreviewEnabled = false
                PickerService.close()
                PickerService.begin(PickerService.Mode.Clipboard,"Clipboard"); PickerService.show()
                root.step++; break
            case 9:
                if (PickerService.searchPending) return
                root.check(!root.panel.previewEnabled && !root.preview.requestedVisible,"clipboard defaults off when inherited global is false")
                root.panel.toggleImagesOnly(); root.step++; break
            case 10:
                if (PickerService.searchPending || !root.preview.visible || root.preview.transitioning) return
                root.layout()
                root.check(root.panel.imagesOnly && root.panel.previewEnabled,"Images only retains its manual preview action")
                PickerService.close(); root.step++; break
            case 11:
                if (root.preview.visible) return
                root.check(!root.preview.previewItem,"closing picker releases companion content")
                root.screenBounds()
                if (!root.failed) console.log("PASS: separate larger floating previews, stable list placement, aspect fit, per-picker/global defaults, manual toggles, screen bounds and sharing cleanup")
                Qt.quit()
            }
        }
    }
}
