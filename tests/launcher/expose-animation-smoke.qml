pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Wayland
import "../../src/modules/launcher"
import "../../src/theme"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    property bool openingIntermediate: false
    property bool openingZoomed: false
    property bool offCenterPlacementChecked: false
    property bool cancellationZoomCompleted: false
    function check(ok, message) { if (!ok) { failed = true; console.error("EXPOSE FAIL:", message) } }
    function checkWorkspaceFillsDesktop() {
        root.check(Math.abs(window.zoomRect.width * window.zoomFactor - window.desktopRect.width) < 1
            && Math.abs(window.zoomRect.height * window.zoomFactor - window.desktopRect.height) < 1,
            "workspace zoom fills both dimensions of the usable desktop without preview padding")
        root.check(window.previewItem.opacity === 1, "workspace closing stays opaque until the zoom finishes")
    }
    Test.TestCase { id: objects; when: false }
    QtObject {
        id: picker
        property bool visible: false
        property string layout: "expose"
        property var targetScreen: Quickshell.screens[0]
        property string query: ""
        property var exposeCloseTarget: null
        readonly property var currentItem: filteredItems[currentIndex] ?? null
        property string focusedAddress: ""
        property int currentIndex: 0
        property bool exposeDragging: false
        property int exposeWorkspace: 1
        property int exposeReturnWorkspace: 1
        property var exposeWorkspaces: [{id: 1, name: "Original"}, {id: 2, name: "Other"},
            {id: 3, name: "Empty"}, {id: -99, name: "special:test"}]
        property var items: [{id: "0x1", result: "0x1", title: "Original", workspaceId: 1,
            client: {address: "0x1", class: "", at: [window.monitorOrigin.x + window.desktopRect.x + window.desktopRect.width / 2 - 400,
                window.monitorOrigin.y + window.desktopRect.y + window.desktopRect.height / 2 - 300], size: [800, 600]}},
            {id: "0x2", result: "0x2", title: "Other", workspaceId: 2,
            client: {address: "0x2", class: "", at: [window.monitorOrigin.x + window.desktopRect.x + window.desktopRect.width / 2 - 300,
                window.monitorOrigin.y + window.desktopRect.y + window.desktopRect.height / 2 - 200], size: [600, 400]}}]
        readonly property var filteredItems: items.filter(item => (!exposeWorkspace || item.workspaceId === exposeWorkspace)
            && (!query || item.title.includes(query)))
        property string error: ""
        function close() { visible = false }
        function finishExposeClose() {
            if (exposeCloseTarget) focusedAddress = exposeCloseTarget.result
            exposeCloseTarget = null
        }
        function move(_delta) {}
        function select(_index, _toggle) {}
        function selectExposeWorkspace(_id) {}
        function moveExposeWindow(_address, _workspace) { return false }
        function accept(_custom, _copy) {}
    }
    ExposeWindow { id: window; picker: picker; reservedMargins: [8, 30, 12, 6] }
    Connections {
        target: window
        function onTransitionProgressChanged() {
            if (root.step <= 5 && window.requested && window.transitionProgress > 0 && window.transitionProgress < 1) {
                root.openingIntermediate = true
                root.openingZoomed = root.openingZoomed || (window.transitionWorkspace === 1 && window.zoomFactor > 1)
            }
            if (root.step > 22 && root.step <= 27 && !window.requested
                && window.transitionProgress > 0 && window.transitionProgress < 0.1) {
                root.checkWorkspaceFillsDesktop()
                root.cancellationZoomCompleted = true
            }
            if (root.step > 32 && root.step <= 37 && !window.requested
                && window.transitionProgress > 0 && window.transitionProgress < 0.1 && !root.offCenterPlacementChecked) {
                // Observe the rendered geometry after camera and miniature bindings have updated.
                Qt.callLater(() => {
                    const preview = objects.findChild(window.previewItem, "exposeWorkspaceWindow-0x1") as WindowPreview
                    const camera = objects.findChild(window.previewItem, "exposeCamera") as Item
                    if (!preview || !camera) return
                    const position = preview.mapToItem(camera, 0, 0)
                    const finalX = window.desktopRect.x + window.desktopRect.width / 2
                        + (position.x - window.zoomRect.x - window.zoomRect.width / 2) * window.zoomFactor
                    const finalY = window.desktopRect.y + window.desktopRect.height / 2
                        + (position.y - window.zoomRect.y - window.zoomRect.height / 2) * window.zoomFactor
                    const client = picker.items.find(entry => entry.id === "0x1").client
                    root.check(Math.abs(finalX - client.at[0] + window.monitorOrigin.x) < 1
                        && Math.abs(finalY - client.at[1] + window.monitorOrigin.y) < 1
                        && Math.abs(preview.width * window.zoomFactor - client.size[0]) < 1
                        && Math.abs(preview.height * window.zoomFactor - client.size[1]) < 1,
                        "workspace zoom lands the off-center window at its actual desktop position and size")
                    root.checkWorkspaceFillsDesktop()
                    root.offCenterPlacementChecked = true
                })
            }
        }
    }
    Timer {
        interval: Theme.exposeAnimationDuration / 3
        running: true
        repeat: true
        onTriggered: {
            if (root.step === 0) {
                root.check(!window.visible, "closed overview starts unmapped")
                picker.visible = true
            } else if (root.step === 1) {
                root.check(window.visible, "opening maps the overview surface")
                root.check(window.transitionWorkspace === picker.exposeReturnWorkspace,
                    "opening targets the starting workspace")
                const fittedWidth = window.zoomRect.width * window.zoomFactor
                const fittedHeight = window.zoomRect.height * window.zoomFactor
                root.check(fittedWidth <= window.desktopRect.width + 1 && fittedHeight <= window.desktopRect.height + 1,
                    "zoom fits the preview inside the desktop's reserved margins without cropping")
                root.check(Math.abs(fittedWidth - window.desktopRect.width) < 1
                    && Math.abs(fittedHeight - window.desktopRect.height) < 1,
                    "opening fits the workspace miniature to both usable desktop dimensions")
            } else if (root.step === 5) {
                root.check(root.openingIntermediate, "opening zooms out over multiple frames")
                root.check(root.openingZoomed, "opening frames the starting workspace at a larger scale")
                root.check(window.transitionProgress === 1, "opening settles at full opacity")
                picker.visible = false
                root.check(window.visible, "closing keeps the surface mapped for the zoom")
                root.checkWorkspaceFillsDesktop()
                root.check(window.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,
                    "closing releases keyboard focus immediately")
            } else if (root.step === 6) {
                root.check(window.visible && window.transitionProgress > 0 && window.transitionProgress < 1,
                    "closing zooms in over multiple frames")
                picker.visible = true
            } else if (root.step === 11) {
                root.check(window.visible && window.transitionProgress === 1,
                    "reopening during the zoom reverses cleanly: visible=" + window.visible + " requested=" + window.requested + " progress=" + window.transitionProgress)
                picker.exposeWorkspace = 2
                picker.exposeCloseTarget = {id: "0x2", result: "0x2", workspaceId: 2}
                picker.visible = false
                root.check(window.transitionWorkspace === 2,
                    "the accepted window's workspace becomes the closing animation destination")
                root.check(picker.focusedAddress === "", "activation waits until the overlay disappears")
                root.check(window.zoomFactor > 1, "accepting a centered window zooms into its workspace miniature")
                root.checkWorkspaceFillsDesktop()
            } else if (root.step === 16) {
                root.check(!window.visible && window.transitionProgress === 0,
                    "closing unmaps the surface after the animation")
                root.check(picker.focusedAddress === "0x2" && picker.exposeCloseTarget === null,
                    "closing activates the selected destination once the overlay disappears")
                window.animationsEnabled = false
                picker.visible = true
                root.check(window.visible && window.transitionProgress === 1, "screen sharing opens without animation")
                picker.visible = false
                root.check(!window.visible && window.transitionProgress === 0, "screen sharing closes without animation")
                window.animationsEnabled = true
                picker.visible = true
            } else if (root.step === 17) {
                root.check(window.transitionProgress > 0 && window.transitionProgress < 1, "animations return after screen sharing")
                window.animationsEnabled = false
                root.check(window.transitionProgress === 1, "starting screen sharing finishes an active transition immediately")
                picker.visible = false
                root.check(!window.visible, "closing still works after disabling a running transition")
                window.animationsEnabled = true
                picker.exposeWorkspace = 1
                picker.focusedAddress = "0x1"
                picker.visible = true
            } else if (root.step === 22) {
                picker.exposeWorkspace = 2
                picker.close()
                root.check(window.transitionWorkspace === 1,
                    "cancellation zooms into the original workspace after switching views")
                root.check(window.zoomRect.width > 0 && window.zoomRect.height > 0,
                    "the workspace miniature is available as a zoom target")
            } else if (root.step === 23) {
                root.checkWorkspaceFillsDesktop()
                root.check(window.cameraScale > 1, "workspace cancellation zooms the whole scene toward the tile")
                const camera = window.previewItem.children.find(child => child.objectName === "exposeCamera") as Item
                const center = camera.mapToItem(window.previewItem,
                    window.zoomRect.x + window.zoomRect.width / 2, window.zoomRect.y + window.zoomRect.height / 2)
                const expectedX = (window.desktopRect.x + window.desktopRect.width / 2) * (1 - window.transitionProgress)
                    + (window.zoomRect.x + window.zoomRect.width / 2) * window.transitionProgress
                const expectedY = (window.desktopRect.y + window.desktopRect.height / 2) * (1 - window.transitionProgress)
                    + (window.zoomRect.y + window.zoomRect.height / 2) * window.transitionProgress
                root.check(Math.abs(center.x - expectedX) < 1 && Math.abs(center.y - expectedY) < 1,
                    "camera moves the zoom target toward the usable desktop center below the bar")
            } else if (root.step === 27) {
                root.check(root.cancellationZoomCompleted, "workspace cancellation remains visible through the end of its zoom")
                root.check(!window.visible && picker.focusedAddress === "0x1",
                    "cancellation returns to the original desktop without selecting the other workspace's window")
                picker.exposeWorkspace = 1
                picker.visible = true
            } else if (root.step === 32) {
                const previousOriginX = window.monitorOrigin.x
                const previousOriginY = window.monitorOrigin.y
                const previousItems = picker.items
                window.monitorOrigin = Qt.point(1400, 900)
                picker.items = previousItems.map(entry => Object.assign({}, entry, {client: Object.assign({}, entry.client, {
                    at: [entry.client.at[0] + window.monitorOrigin.x - previousOriginX,
                        entry.client.at[1] + window.monitorOrigin.y - previousOriginY]
                })}))
                picker.items = picker.items.map(entry => entry.id !== "0x1" ? entry : Object.assign({}, entry, {
                    client: Object.assign({}, entry.client, {at: [entry.client.at[0] - window.desktopRect.width / 4, entry.client.at[1]]})
                }))
                picker.exposeCloseTarget = {id: "0x1", result: "0x1", workspaceId: 1}
                picker.visible = false
                root.check(window.transitionWorkspace === 1 && window.zoomFactor > 1,
                    "accepting an off-center window zooms into its workspace layout")
                root.checkWorkspaceFillsDesktop()
            } else if (root.step === 37) {
                root.check(root.offCenterPlacementChecked, "off-center workspace zoom reaches its final desktop geometry")
                root.check(!window.visible && picker.focusedAddress === "0x1",
                    "workspace zoom still activates the selected off-center window after closing")
                picker.exposeReturnWorkspace = 3
                picker.exposeWorkspace = 0
                picker.query = "No match"
                picker.visible = true
            } else if (root.step === 38) {
                root.check(window.transitionWorkspace === 3 && window.zoomFactor > 1,
                    "All view opens from the empty starting workspace even when search hides every window")
                root.check(Math.abs(window.zoomRect.width * window.zoomFactor - window.desktopRect.width) < 1
                    && Math.abs(window.zoomRect.height * window.zoomFactor - window.desktopRect.height) < 1,
                    "empty workspace opening uses its fitted desktop miniature")
            } else if (root.step === 42) {
                picker.close()
                root.check(window.transitionWorkspace === 3, "filtered All view dismisses to the empty starting workspace")
                root.checkWorkspaceFillsDesktop()
            } else if (root.step === 47) {
                root.check(!window.visible, "empty workspace cancellation completes")
                picker.query = ""
                picker.items = picker.items.concat([{id: "0x3", result: "0x3", title: "Special", workspaceId: -99,
                    client: Object.assign({}, picker.items[1].client, {address: "0x3"})}])
                picker.exposeWorkspace = 0
                picker.visible = true
            } else if (root.step === 52) {
                picker.exposeCloseTarget = picker.items.find(entry => entry.id === "0x3")
                picker.close()
                root.check(window.transitionWorkspace === -99 && window.zoomFactor > 1,
                    "accepting a special-workspace window targets its workspace miniature")
                root.checkWorkspaceFillsDesktop()
            } else if (root.step === 57) {
                root.check(!window.visible && picker.focusedAddress === "0x3",
                    "special-workspace acceptance activates only after the animation completes")
                console.log(root.failed ? "EXPOSE FAIL: animation" : "PASS: Exposé workspace transitions, centered/off-center destinations, monitor origins, cancellation, empty and special workspaces, filtered All view, focus release and screen-sharing suppression")
                stop()
                Qt.quit()
            }
            root.step++
        }
    }
}
