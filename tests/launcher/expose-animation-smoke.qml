pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../src/modules/launcher"
import "../../src/theme"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    function check(ok, message) { if (!ok) { failed = true; console.error("EXPOSE FAIL:", message) } }
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
        property var exposeWorkspaces: [{id: 1, name: "Original"}, {id: 2, name: "Other"}]
        property var items: [{id: "0x1", result: "0x1", title: "Original", workspaceId: 1,
            client: {address: "0x1", class: "", at: [0, 0], size: [800, 600]}},
            {id: "0x2", result: "0x2", title: "Other", workspaceId: 2,
            client: {address: "0x2", class: "", at: [0, 0], size: [600, 400]}}]
        readonly property var filteredItems: items.filter(item => item.workspaceId === exposeWorkspace)
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
    Timer {
        interval: Theme.exposeAnimationDuration / 3
        running: true
        repeat: true
        onTriggered: {
            if (root.step === 0) {
                root.check(!window.visible, "closed overview starts unmapped")
                picker.visible = true
            } else if (root.step === 1) {
                root.check(window.visible && window.transitionProgress > 0 && window.transitionProgress < 1,
                    "opening zooms out over multiple frames")
                root.check(window.zoomTarget === "window" && window.cameraScale > 1,
                    "opening frames the focused preview at a larger scale")
                const fittedWidth = window.zoomRect.width * window.zoomFactor
                const fittedHeight = window.zoomRect.height * window.zoomFactor
                root.check(fittedWidth <= window.desktopRect.width + 1 && fittedHeight <= window.desktopRect.height + 1,
                    "zoom fits the preview inside the desktop's reserved margins without cropping")
                root.check(Math.abs(fittedWidth - window.desktopRect.width) < 1
                    || Math.abs(fittedHeight - window.desktopRect.height) < 1,
                    "zoom uses the largest scale that fits the usable desktop")
            } else if (root.step === 5) {
                root.check(window.transitionProgress === 1, "opening settles at full opacity")
                picker.visible = false
                root.check(window.visible, "closing keeps the surface mapped for the fade")
                root.check(window.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,
                    "closing releases keyboard focus immediately")
            } else if (root.step === 6) {
                root.check(window.visible && window.transitionProgress > 0 && window.transitionProgress < 1,
                    "closing fades out over multiple frames")
                picker.visible = true
            } else if (root.step === 11) {
                root.check(window.visible && window.transitionProgress === 1,
                    "reopening during the fade reverses cleanly: visible=" + window.visible + " requested=" + window.requested + " opacity=" + window.transitionProgress)
                picker.exposeWorkspace = 2
                picker.exposeCloseTarget = {id: "0x2", result: "0x2", workspaceId: 2}
                picker.visible = false
                root.check(window.transitionWorkspace === 2 && window.transitionAddress === "0x2",
                    "accepted window becomes the closing animation destination")
                root.check(picker.focusedAddress === "", "activation waits until the overlay disappears")
                root.check(window.zoomTarget === "window" && window.zoomFactor > 1, "acceptance zooms the selected preview up to fit the usable desktop")
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
                root.check(window.zoomTarget === "workspace" && window.transitionWorkspace === 1,
                    "cancellation zooms into the original workspace when its window preview is hidden")
                root.check(window.zoomRect.width > 0 && window.zoomRect.height > 0,
                    "the workspace miniature is available as a zoom target")
            } else if (root.step === 23) {
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
                root.check(!window.visible && picker.focusedAddress === "0x1",
                    "cancellation returns to the original desktop without selecting the other workspace's window")
                console.log(root.failed ? "EXPOSE FAIL: animation" : "PASS: Exposé zooming, full-view zoom, selected preview, workspace cancellation, immediate focus release and screen-sharing suppression")
                stop()
                Qt.quit()
            }
            root.step++
        }
    }
}
