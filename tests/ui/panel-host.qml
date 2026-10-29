pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Wayland
import "../../src/ui/panels"
import "../../src/ui" as UI
import "../../src/services"

WorkerScope {
    id: root
    property int phase: 0
    property int frames: 0
    property int attempts: 0
    property real nativeHeight: 0
    property real nativeTop: 0
    property real tallHeight: 0
    property bool failed: false
    readonly property UI.TabBar tabs: body.loadedContent
        ? objects.findChild(body.loadedContent,"hostTabs") as UI.TabBar : null
    function check(ok, message) { if (!ok) { failed = true; console.error("HOST FAIL:", message) } }
    Test.TestResult { id: objects }
    Component {
        id: content
        Column {
            width: 300
            UI.TabBar { id: tabs; objectName: "hostTabs"; labels: ["Overview", "CPU"]; currentIndex: 1; width: parent.width }
            Rectangle { width: parent.width; height: tabs.currentIndex === 1 ? 400 : 100; color: "#6b8fb3" }
        }
    }
    TopPanelTooltip {
        id: panelWindow
        implicitWidth: 620
        requestedVisible: true
        contentWidth: body.implicitWidth + 40
        contentHeight: body.implicitHeight + 20
        contentX: 100
        exclusionMode: ExclusionMode.Ignore
        mask: Region { width: 0; height: 0 }
        WlrLayershell.namespace: "quickshell-host-check"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        TooltipContent { id: body; host: panelWindow; anchors.fill: parent }
    }
    Component.onCompleted: {
        panelWindow.surfaceComponent.motion.motionEnabled = false
        TooltipService.show(100,content,null,false)
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (++root.attempts > 100) { root.check(false,"native host did not settle"); Qt.quit(); return }
            switch (root.phase) {
            case 0:
                if (!root.tabs || !panelWindow.visible || panelWindow.transitioning) return
                root.check(panelWindow.revealBarOverFullscreen,
                    "top-attached panels reveal their bar over fullscreen windows by default")
                root.nativeHeight = panelWindow.height
                root.nativeTop = panelWindow.contentItem.mapToGlobal(0,0).y
                root.tallHeight = panelWindow.contentHeight
                root.tabs.currentIndex = 0
                root.phase = 1
                break
            case 1:
            case 2:
                root.check(panelWindow.height === root.nativeHeight,
                    "tab switches must never resize the mapped native buffer")
                root.check(panelWindow.contentItem.mapToGlobal(0,0).y === root.nativeTop,
                    "tab switches must not move the native surface")
                root.check(panelWindow.surfaceComponent.inputRect.height === panelWindow.contentHeight
                    && panelWindow.surfaceComponent.inputRect.height < panelWindow.height,
                    "only the visible panel extent participates in input")
                root.check(panelWindow.surfaceComponent.motion.contentOpacity === 1 && !panelWindow.transitioning,
                    "disabled animations switch content immediately")
                if (++root.frames < 8) return
                root.frames = 0
                if (root.phase === 1) {
                    root.check(panelWindow.contentHeight < root.tallHeight,"Overview shrinks the visible panel")
                    root.tabs.currentIndex = 1
                    root.phase = 2
                    return
                }
                root.check(panelWindow.contentHeight === root.tallHeight,"CPU restores the larger visible panel")
                panelWindow.requestedVisible = false
                root.check(!panelWindow.visible && panelWindow.surfaceComponent.inputRect.height === 0,
                    "closing releases presentation and input with motion disabled")
                console.log(root.failed ? "HOST FAIL: native geometry" : "PASS: stable native panel buffer across shrinking and growing tabs, with visible-size input and animations disabled")
                Qt.quit()
                break
            }
        }
    }
}
