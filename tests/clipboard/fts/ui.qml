pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../../src/modules/launcher"
import "../../../src/services"
import "../../../src/theme"
import "../../../src/ui" as UI

Scope {
    id: root
    property int step: 0
    property int ticks: 0
    property bool failed: false
    property bool sawMotion: false
    property bool sawExit: false
    property string selection: ""
    property real originalWidth: 0
    property real originalHeight: 0
    property string monitorSelection: ""
    property bool capturingPreview: false
    property bool screenshotSaved: false
    readonly property bool nativeTest: Quickshell.env("CLIPBOARD_NATIVE") === "1"
    readonly property bool narrowTest: Quickshell.env("CLIPBOARD_NARROW") === "1"
    readonly property bool zeroMotion: Quickshell.env("CLIPBOARD_ZERO_MOTION") === "1"
    readonly property var nativeHostItem: nativeHost.item
    readonly property var popup: nativeHostItem?.window
    readonly property var panel: nativeTest ? popup?.panel?.panel : floatingLoader.item
    readonly property var companion: nativeTest ? popup?.floatingPreviewWindow : floatingPreview
    function check(ok,message) { if (!ok) { failed = true; console.error("CLIPBOARD FAIL:",message) } }
    function find(item,name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const match = find(child,name); if (match) return match }
        return null
    }
    Test.TestEvent { id: events }
    Loader { id: nativeHost; active: root.nativeTest; source: Qt.resolvedUrl("native-host.qml") }
    QtObject {
        id: floatingHost
        property var requestedScreen: Quickshell.screens[0]
        property bool requestedVisible: PickerService.visible && !root.nativeTest
        property real contentHeight: floatingLoader.height
        property real layoutContentHeight: contentHeight
        property real shadowBottomPadding: 0
    }
    FloatingWindow {
        visible: !root.nativeTest && floatingPreview.presented
        implicitWidth: floatingHost.requestedScreen.width
        implicitHeight: floatingHost.requestedScreen.height - Theme.barHeight
        PickerPreviewSurface { id: floatingPreview; anchors.fill: parent; host: floatingHost; picker: PickerService; previewPanel: root.panel }
    }
    FloatingWindow {
        visible: !root.nativeTest
        implicitWidth: 1600; implicitHeight: 800
        Loader {
            id: floatingLoader
            active: !root.nativeTest
            sourceComponent: ClipboardPickerPanel {
                availableContentWidth: root.narrowTest ? 600 : 1560
                availableContentHeight: 760
            }
            anchors.centerIn: parent
            width: (item as Item)?.implicitWidth ?? Theme.pickerWidth
            height: Math.min((item as Item)?.implicitHeight ?? 0,(item as ClipboardPickerPanel)?.floatingPreviewRequested ? 200 : 760)
        }
    }
    Timer {
        interval: 15; repeat: true; running: true
        onTriggered: {
            if (++root.ticks > 1600 || root.failed) { stop(); console.error("CLIPBOARD FAIL: stopped at step",root.step); PickerService.close(); Qt.quit(); return }
            if (!DbService.ready) return
            if (root.capturingPreview) return
            if (root.step === 0) {
                DbService.write(tx => {
                    for (let i = 0; i < 132; i++) {
                        const text = i === 42 ? "x".repeat(400) + " NeedlePhrase" : "clipboard fixture " + i
                        tx.executeSql("INSERT INTO store.clipboard(id,mime,kind,bytes,text,updated_at,pinned) VALUES(?,?,?,?,?,?,?)",
                            [(i+1).toString(16).padStart(64,"0"),i < 4 ? "image/png" : "text/plain",i < 4 ? "image" : "text",100,text,1000-i,i === 0 ? 1 : 0])
                    }
                })
                ClipboardRepository.revision++
                PickerService.begin(PickerService.Mode.Clipboard,"Clipboard")
                PickerService.destination = "fixture-window"
                PickerService.show(); root.step++; return
            }
            if (!root.panel) return
            if (root.step === 1) {
                if (PickerService.searchPending) return
                root.check(PickerService.items.length === 50 && PickerService.clipboardHasMore,"bounded first page")
                root.check(PickerService.items.every(row => !row.search && !row.result.hasOwnProperty("text")),"metadata DTOs exclude full text")
                root.selection = PickerService.currentItem.id
                PickerService.loadMoreClipboard(); root.step++; return
            }
            if (root.step === 2) {
                if (PickerService.searchPending) return
                root.check(PickerService.items.length >= 100 && PickerService.currentItem?.id === root.selection,"paging preserves stable selection")
                PickerService.select(75,false)
                root.selection = PickerService.filteredItems[PickerService.currentIndex]?.id ?? ""
                ClipboardRepository.add({id:"f".repeat(64),mime:"text/plain",kind:"text",bytes:3,text:"new"})
                root.step = 20; return
            }
            if (root.step === 20) {
                if (PickerService.searchPending) return
                root.check(PickerService.currentItem?.id === root.selection,"capture preserves selection on later pages")
                PickerService.query = "needle"; root.step = 3; return
            }
            if (root.step === 3) {
                if (PickerService.searchPending) return
                root.check(PickerService.items.length === 1,"indexed search reaches beyond preview")
                PickerService.query = "nph"; root.step++; return
            }
            if (root.step === 4) {
                if (PickerService.searchPending) return
                root.check(PickerService.items.length === 0,"indexed search does not silently fuzzy-match")
                PickerService.clipboardFuzzy = true; root.step++; return
            }
            if (root.step === 5) {
                if (PickerService.searchPending) return
                root.check(PickerService.items.length === 1,"fuzzy-only match remains available")
                PickerService.clipboardFuzzy = false; PickerService.query = ""; root.step++; return
            }
            if (root.step === 6) {
                if (PickerService.searchPending) return
                root.panel.focusSearch()
                events.keyClick(Qt.Key_I,Qt.ControlModifier | Qt.ShiftModifier,0)
                root.check(root.panel.imagesOnly,"image shortcut works from search")
                root.step++; return
            }
            if (root.step === 7) {
                if (PickerService.searchPending || root.companion.transitioning) return
                root.check(root.panel.floatingPreviewRequested && root.panel.width === Theme.pickerWidth,"floating mode keeps normal list width")
                root.check(PickerService.filteredItems.length === 4 && PickerService.destination === "fixture-window","image criteria and paste destination")
                if (root.nativeTest) root.check(root.find(root.panel,"pickerSearch").activeFocus,"floating preview preserves native search focus")
                const image = root.find(root.nativeTest ? root.companion.contentItem : root.companion,"clipboardLargeImage") as UI.ScaledImage
                if (!image || image.status !== Image.Ready) return
                root.check(image.mipmap && image.smooth && image.fillMode === Image.PreserveAspectFit && !image.cache,"shared floating image settings")
                root.check(root.companion.previewWidth > root.panel.width,"preview is wider than the list")
                const hints = root.find(root.panel,"pickerFooterHint") as UI.ShortcutHints
                const actions = root.find(root.panel,"pickerFooterActions") as Item
                root.check(hints.y >= actions.y + actions.height,"hint row remains below actions")
                const output = Quickshell.env("CLIPBOARD_PREVIEW_OUTPUT")
                if (output && !root.screenshotSaved) {
                    root.capturingPreview = true
                    const surface = root.nativeTest ? root.companion.contentItem : root.companion
                    surface.grabToImage(result => {
                        result.saveToFile(output)
                        root.screenshotSaved = true; root.capturingPreview = false
                    })
                    return
                }
                root.monitorSelection = PickerService.currentItem?.id ?? ""
                root.originalWidth = root.panel.availableContentWidth
                root.originalHeight = root.panel.availableContentHeight
                root.panel.availableContentWidth = 600
                root.panel.availableContentHeight = 400
                root.step = 70; return
            }
            if (root.step === 70) {
                root.check(root.panel.floatingPreviewRequested && root.panel.width <= 600,"monitor geometry preserves compact list and companion request")
                root.panel.availableContentWidth = root.originalWidth
                root.panel.availableContentHeight = root.originalHeight
                root.step = 71; return
            }
            if (root.step === 71) {
                root.check(root.panel.floatingPreviewRequested && PickerService.currentItem?.id === root.monitorSelection,"restoring monitor geometry preserves selection and focus")
                root.panel.togglePinnedOnly(); root.step = 8; return
            }
            if (root.step === 8) {
                if (PickerService.searchPending) return
                root.check(PickerService.itemCriteria.kind === "image" && PickerService.itemCriteria.pinned && PickerService.items.length === 1,"filters compose")
                root.panel.toggleImagesOnly(); root.step++; return
            }
            if (root.step === 9) {
                if (PickerService.searchPending || root.companion.transitioning) return
                root.check(PickerService.itemCriteria.pinned && !PickerService.itemCriteria.kind,"exit animation retains pin criterion")
                root.check(root.panel.width <= Theme.pickerWidth,"compact width restored")
                DbService.write(tx => tx.executeSql("DROP TABLE store.clipboard_fts"))
                root.panel.togglePinnedOnly()
                PickerService.query = "fixture"
                root.step = 30; return
            }
            if (root.step === 30) {
                if (PickerService.searchPending) return
                root.check(PickerService.searchFailed && !PickerService.canAccept,"failed search cannot activate stale rows")
                PickerService.clipboardFuzzy = true
                root.step = 31; return
            }
            if (root.step === 31) {
                if (PickerService.searchPending) return
                root.check(!PickerService.searchFailed && PickerService.canAccept,"fuzzy fallback works with missing index")
                PickerService.query = ""
                root.panel.toggleImagesOnly(); root.step = 10; return
            }
            if (root.step === 10) {
                root.panel.toggleImagesOnly(); root.panel.toggleImagesOnly()
                AudioService.screencastActive = true
                root.check(!UI.MotionPolicy.enabled && root.companion.requestedVisible && !root.companion.transitioning,"disabled motion settles an interrupted transition immediately")
                AudioService.screencastActive = false
                PickerService.close(); root.step++; return
            }
            stop()
            root.check(!PickerService.items.length && !PickerService.searchPending && !root.panel.floatingPreviewRequested,"close cancels motion and releases rows")
            PickerService.begin(PickerService.Mode.Menu,"Other launcher")
            PickerService.items = [{id:"menu",title:"Menu"}]
            PickerService.show()
            root.check(PickerService.currentItem?.id === "menu","late clipboard work cannot replace another launcher")
            PickerService.close()
            console.log("PASS: indexed/fuzzy search, paging, shared images, composed filters, floating preview, reversal and close cleanup")
            Qt.quit()
        }
    }
}
