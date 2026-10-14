pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../../src/modules/launcher"
import "../../../src/services"
import "../../../src/theme"
import "../../../src/theme/ui" as UI

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
    function check(ok,message) { if (!ok) { failed = true; console.error("CLIPBOARD FAIL:",message) } }
    function find(item,name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const match = find(child,name); if (match) return match }
        return null
    }
    Test.TestEvent { id: events }
    Loader { id: nativeHost; active: root.nativeTest; source: Qt.resolvedUrl("native-host.qml") }
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
            height: Math.min((item as Item)?.implicitHeight ?? 0,760)
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
                if (root.panel.imageProgress > 0 && root.panel.imageProgress < 1) {
                    root.sawMotion = true
                    root.check(Math.abs(root.find(root.panel,"pickerList").width - (Theme.pickerWidth - Theme.tooltipPaddingHeight * 2)) < 1,"list width stays constant during travel")
                    if (root.nativeTest) root.check(Math.abs(popup.mask.width - popup.contentWidth) < 1
                        && Math.abs(popup.mask.x - popup.contentX) < 1
                        && Math.abs(popup.contentX - (popup.width - popup.contentWidth) / 2) < 1,"native input mask follows animated centered content")
                }
                if (PickerService.searchPending || root.panel.imageProgress !== 1) return
                root.check((root.sawMotion || root.zeroMotion) && (root.narrowTest ? root.panel.stackedPreview : root.panel.width > Theme.pickerWidth),"wide or stacked transition")
                root.check(PickerService.filteredItems.length === 4 && PickerService.destination === "fixture-window","image criteria and paste destination")
                root.check(root.find(root.panel,"pickerSearch").activeFocus,"transition preserves search focus")
                const image = root.find(root.panel,"clipboardLargeImage") as UI.ScaledImage
                if (!image || image.status !== Image.Ready) return
                root.check(image.mipmap && image.smooth && image.fillMode === Image.PreserveAspectFit && !image.cache,"shared image settings")
                const hints = root.find(root.panel,"pickerFooterHint") as UI.ShortcutHints
                const actions = root.find(root.panel,"pickerFooterActions") as Item
                const hintCenter = hints.mapToItem(root.panel,hints.width / 2,hints.height / 2)
                const actionCenter = actions.mapToItem(root.panel,actions.width / 2,actions.height / 2)
                root.check(Math.abs(hintCenter.x - root.panel.width / 2) < 1,"footer hints stay centered across the panel")
                if (!root.narrowTest) {
                    root.check(Math.abs(hintCenter.y - actionCenter.y) < 1,"wide image hints and buttons share one line")
                    root.check(hints.x + hints.width <= actions.x,"centered hints do not overlap right-aligned actions")
                } else root.check(hints.y >= actions.y + actions.height,"compact footer keeps hints below actions")
                if (root.nativeTest) root.check(popup.contentWidth > Theme.pickerWidth,"nativeTest surface expands")
                const output = Quickshell.env("CLIPBOARD_PREVIEW_OUTPUT")
                if (output && !root.screenshotSaved) {
                    root.capturingPreview = true
                    root.panel.grabToImage(result => {
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
                root.check(root.panel.stackedPreview && root.panel.width <= 600,"monitor geometry change switches to bounded stacked layout")
                root.panel.availableContentWidth = root.originalWidth
                root.panel.availableContentHeight = root.originalHeight
                root.step = 71; return
            }
            if (root.step === 71) {
                root.check(root.panel.stackedPreview === root.narrowTest && PickerService.currentItem?.id === root.monitorSelection
                    && root.find(root.panel,"pickerSearch").activeFocus,"restoring monitor geometry preserves selection and focus")
                root.panel.togglePinnedOnly(); root.step = 8; return
            }
            if (root.step === 8) {
                if (PickerService.searchPending) return
                root.check(PickerService.itemCriteria.kind === "image" && PickerService.itemCriteria.pinned && PickerService.items.length === 1,"filters compose")
                root.panel.toggleImagesOnly(); root.step++; return
            }
            if (root.step === 9) {
                if (root.panel.imageProgress > 0 && root.panel.imageProgress < 1) root.sawExit = true
                if (PickerService.searchPending || root.panel.imageProgress !== 0) return
                root.check((root.sawExit || root.zeroMotion) && PickerService.itemCriteria.pinned && !PickerService.itemCriteria.kind,"exit animation retains pin criterion")
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
                if (!root.zeroMotion && !(root.panel.imageProgress > 0 && root.panel.imageProgress < 1)) return
                root.panel.toggleImagesOnly(); root.panel.toggleImagesOnly()
                AudioService.screencastActive = true
                root.check(!root.panel.motionEnabled && root.panel.imageProgress === 1,"disabled motion settles an interrupted transition immediately")
                AudioService.screencastActive = false
                PickerService.close(); root.step++; return
            }
            stop()
            root.check(!PickerService.items.length && !PickerService.searchPending && root.panel.imageProgress === 0,"close cancels motion and releases rows")
            PickerService.begin(PickerService.Mode.Menu,"Other launcher")
            PickerService.items = [{id:"menu",title:"Menu"}]
            PickerService.show()
            root.check(PickerService.currentItem?.id === "menu","late clipboard work cannot replace another launcher")
            PickerService.close()
            console.log("PASS: indexed/fuzzy search, paging, shared images, composed filters, animated travel/pop, reversal, focus and close cleanup")
            Qt.quit()
        }
    }
}
