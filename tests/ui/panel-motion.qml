pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/ui/panels"
import "../../src/ui" as UI
import "../../src/services"
import "../../src/config"
import "../../src/theme"
import "../../src/modules/system/notifications"
import "../../src/modules/system/audio" as Audio

Scope {
    id: root
    property bool failed: false
    property var fakeAudio: AudioService
    property var fakeConfig: Config
    property bool trackingCenteredResize: false
    property int resizeDirection: 1
    property int resizeSamples: 0
    property real previousWidth: 0
    property real previousHeight: 0
    function check(ok, message) { if (!ok) { failed = true; console.error("MOTION FAIL:", message) } }
    QtObject { id: tweenTarget; property real value: 0 }
    UI.MotionAnimation { id: tween; target: tweenTarget; property: "value"; from: 0; to: 100; animationDuration: 200 }
    QtObject { id: behaviorSource; property real value: 0 }
    Item {
        id: behaviorTarget
        property real value: behaviorSource.value
        UI.MotionBehavior on value { UI.MotionAnimation { animationDuration: 200 } }
    }
    QtObject { id: loopTarget; property real value: 0 }
    UI.MotionAnimation { id: looping; target: loopTarget; property: "value"; from: 0; to: 100; animationDuration: 200; loops: Animation.Infinite }
    Test.TestCase { id: events; when: false }
    Audio.MediaVisualizer { id: policyVisualizer; active: true; playing: true; visible: false }
    Audio.MediaCavaShader {
        id: policyShader
        preset: "orion_circle_rotate"; bands: [0.5]
        active: true; playing: true; visible: false
    }
    readonly property var centered: centeredSurface.motion
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 900
        readonly property var surfaceComponent: centeredSurface
        TopPanelSurface {
            id: centeredSurface
            anchors.fill: parent
            centeredResize: true
            contentX: (width - contentWidth) / 2
            contentWidth: Theme.pickerWidth
            contentHeight: Theme.pickerHeight
            UI.TabBar { id: centeredTabs; width: parent.width; labels: ["Projects", "Manage"] }
            UI.TabBar { id: sideActionTabs; y: Theme.controlHeight; width: parent.width - 40; labels: ["History", "Emitters"] }
        }
    }
    function trackResize(direction) {
        resizeDirection = direction
        previousWidth = root.centered.displayedWidth
        previousHeight = root.centered.displayedHeight
        resizeSamples = 0
        trackingCenteredResize = true
    }
    FrameAnimation {
        running: root.trackingCenteredResize
        onTriggered: {
            root.resizeSamples++
            root.check(Math.abs(root.centered.displayedX + root.centered.displayedWidth / 2 - 500) < 0.01,
                "centered resizing keeps both edges symmetric on every frame")
            for (const header of [{tabs:centeredTabs,center:500},{tabs:sideActionTabs,center:480}]) {
                const first = header.tabs.itemAt(0), last = header.tabs.itemAt(header.tabs.count - 1)
                const left = first.mapToItem(centeredSurface,0,0).x
                const right = last.mapToItem(centeredSurface,last.width,0).x
                root.check(Math.abs((left + right) / 2 - header.center) < 1,
                    "tabs stay centered on their displayed header line throughout resizing")
            }
            root.check(root.centered.displayedWidth >= Theme.pickerWidth && root.centered.displayedWidth <= Theme.manageWidth
                && root.centered.displayedHeight >= Theme.pickerHeight && root.centered.displayedHeight <= Theme.manageHeight,
                "Manage expansion/contraction never exceeds either endpoint")
            root.check((root.centered.displayedWidth - root.previousWidth) * root.resizeDirection >= -0.01
                && (root.centered.displayedHeight - root.previousHeight) * root.resizeDirection >= -0.01,
                "dimensions move monotonically toward the requested view")
            root.previousWidth = root.centered.displayedWidth
            root.previousHeight = root.centered.displayedHeight
        }
    }
    FloatingWindow {
        id: host
        readonly property var surfaceComponent: surface
        visible: true
        implicitWidth: 800
        implicitHeight: 620
        NotificationCard {
            id: countdown
            x: 500; y: 20; width: 260
            popup: true
            entry: ({liveId:42,emitterKey:"test:motion",summary:"Synthetic countdown",body:"",urgency:1,
                deadline:Date.now()+60000,duration:60000,actions:[]})
        }
        TopPanelSurface {
            id: surface
            width: 800
            height: 620
            contentX: 100
            contentWidth: 300
            contentHeight: 180
            UI.TabBar { id: tabs; width: parent.width; labels: ["First", "Second", "Third"] }
            UI.ColumnText { anchors.centerIn: parent; text: "Panel motion · " + tabs.currentIndex }
        }
    }
    Component {
        id: resizingTabContent
        Column {
            width: 280
            spacing: Theme.controlSpacing
            UI.TabBar { id: resizeTabs; objectName: "resizingTabs"; labels: ["Overview", "CPU"]; currentIndex: 1; width: parent.width }
            Rectangle { width: parent.width; height: resizeTabs.currentIndex === 1 ? 350 : 100; color: Theme.accent }
        }
    }
    FloatingWindow {
        id: layoutHost
        property alias requestedVisible: layoutSurface.requestedVisible
        property alias contentKey: layoutSurface.contentKey
        readonly property var surfaceComponent: layoutSurface
        visible: true
        implicitWidth: 480
        implicitHeight: 620
        TopPanelSurface {
            id: layoutSurface
            width: 480; height: 620
            requestedVisible: true
            contentWidth: layoutKeys.implicitWidth + Theme.tooltipPaddingWidth * 2
            contentHeight: layoutKeys.implicitHeight + Theme.tooltipPaddingHeight * 2
            TooltipContent { id: layoutKeys; host: layoutHost; anchors.fill: parent }
        }
    }
    Timer {
        interval: 50
        running: true
        onTriggered: {
            try {
                root.check(UI.MotionPolicy.allowsMotion(false,false) && UI.MotionPolicy.allowsMotion(true,true)
                    && !UI.MotionPolicy.allowsMotion(false,true), "sharing gate honors config and active sharing")
                centeredSurface.requestedVisible = true
                events.tryCompare(root.centered,"transitioning",false,500)
                root.trackResize(1)
                centeredSurface.contentWidth = Theme.manageWidth
                centeredSurface.contentHeight = Theme.manageHeight
                events.wait(35)
                root.check(root.centered.displayedWidth > Theme.pickerWidth && root.centered.displayedWidth < Theme.manageWidth,
                    "list to Manage interpolates its width")
                events.tryCompare(root.centered,"transitioning",false,500)
                root.check(root.resizeSamples > 0 && root.centered.displayedWidth === Theme.manageWidth
                    && root.centered.displayedHeight === Theme.manageHeight,"Manage expansion reaches its exact dimensions")
                root.trackResize(-1)
                centeredSurface.contentWidth = Theme.pickerWidth
                centeredSurface.contentHeight = Theme.pickerHeight
                events.wait(35)
                root.check(root.centered.displayedWidth > Theme.pickerWidth && root.centered.displayedWidth < Theme.manageWidth,
                    "Manage to list interpolates its width")
                events.tryCompare(root.centered,"transitioning",false,500)
                root.check(root.resizeSamples > 0 && root.centered.displayedWidth === Theme.pickerWidth
                    && root.centered.displayedHeight === Theme.pickerHeight,"list contraction reaches its exact dimensions")
                root.trackResize(1)
                centeredSurface.contentWidth = Theme.manageWidth
                centeredSurface.contentHeight = Theme.manageHeight
                events.wait(35)
                root.trackResize(-1)
                centeredSurface.contentWidth = Theme.pickerWidth
                centeredSurface.contentHeight = Theme.pickerHeight
                events.wait(1)
                events.tryCompare(root.centered,"transitioning",false,500)
                root.check(root.centered.displayedWidth === Theme.pickerWidth && root.centered.displayedHeight === Theme.pickerHeight,
                    "reversing a Manage resize settles on the latest view")
                root.trackingCenteredResize = false
                centeredSurface.requestedVisible = false
                const shadowSource = events.findChild(surface, "topPanelShadowSource") as Item
                const shadow = events.findChild(surface, "topPanelShadow") as Item
                const shadowTop = shadow.mapToItem(surface, 0, 0).y
                const sourceTop = shadowSource.mapToItem(surface, 0, 0).y
                surface.motion.motionEnabled = true
                root.check(surface.shadowVisibility === 0, "closed panel shadow is transparent")
                root.check(!surface.presented && surface.inputRect.width === 0, "hidden panels have no input region")
                surface.requestedVisible = true
                events.wait(35)
                root.check(surface.presented && surface.motion.progress > 0 && surface.motion.progress < 1,
                    "opening reveals the panel from the top")
                root.check(surface.motion.offsetY < 0 && surface.inputRect.height < 180,
                    "input follows only the visible dropdown")
                root.check(shadow.mapToItem(surface, 0, 0).y === shadowTop
                    && shadowSource.mapToItem(surface, 0, 0).y === sourceTop,
                    "bar shadow stays anchored while the panel drops down")
                root.check(surface.shadowVisibility > 0 && surface.shadowVisibility < 1,
                    "bar shadow fades into position during opening")
                events.tryCompare(surface.motion,"transitioning",false,500)
                events.tryCompare(surface,"shadowVisibility",1,300)
                root.check(surface.motion.displayedHeight === 180 && surface.motion.progress === 1,
                    "opening settles quickly at the exact target")
                tabs.currentIndex = 1
                events.wait(1)
                root.check(surface.motion.contentOpacity < 1 && surface.motion.progress === 1
                    && surface.motion.displayedHeight === 180 && surface.motion.displayedWidth === 300,
                    "same-size tab changes fade content without moving or reopening the panel")
                root.check(surface.shadowVisibility === 1 && shadow.mapToItem(surface,0,0).y === shadowTop,
                    "tab changes never fade or move the background shadow")
                events.wait(35)
                root.check(surface.motion.contentOpacity > 0 && surface.motion.contentOpacity < 1 && tabs.enabled,
                    "tab content fades while controls stay interactive")
                tabs.currentIndex = 2
                tabs.currentIndex = 0
                events.wait(1)
                events.tryCompare(surface.motion,"transitioning",false,500)
                root.check(tabs.currentIndex === 0 && surface.motion.contentOpacity === 1,
                    "rapid tab changes settle on the latest choice without queued transitions")
                surface.contentHeight = 400; surface.contentWidth = 520; surface.contentX = 60
                events.wait(35)
                root.check(surface.motion.displayedHeight > 180 && surface.motion.displayedHeight < 400
                    && surface.motion.displayedWidth > 300 && surface.motion.displayedWidth < 520,
                    "panel extension interpolates width and height")
                root.check(surface.motion.displayedX === 60, "panel position never glides sideways")
                root.check(surface.motion.contentOpacity > 0 && surface.motion.contentOpacity < 1,
                    "incoming content fades while its frame resizes")
                root.check(surface.motion.reservedHeight >= 400, "growth reserves the full native render area once")
                const captureHeight = shadowSource.height
                events.wait(20)
                root.check(shadowSource.height === captureHeight, "shadow capture size stays fixed during resize")
                surface.contentHeight = 240; surface.contentWidth = 360
                events.tryCompare(surface.motion,"transitioning",false,500)
                root.check(surface.motion.displayedHeight === 240 && surface.motion.displayedWidth === 360,
                    "rapid retargeting settles on the latest size without a queue")
                surface.contentX = 300
                surface.contentKey = "another module"
                surface.contentHeight = 200
                surface.contentWidth = 280
                root.check(surface.motion.progress === 0, "replacing a module hides its new content before layout")
                root.check(surface.shadowVisibility === 1 && shadow.mapToItem(surface, 0, 0).y === shadowTop,
                    "switching modules never resets or moves the bar shadow")
                events.wait(35)
                root.check(surface.motion.displayedX === 300 && surface.motion.displayedWidth === 280
                    && surface.motion.offsetY < 0, "new module drops vertically from its own final anchor")
                events.tryCompare(surface.motion,"transitioning",false,500)
                surface.requestedVisible = false
                root.check(surface.presented && surface.inputRect.width === 0 && !surface.popupContentBounds.enabled,
                    "closing keeps presentation alive but releases input immediately")
                events.wait(35)
                root.check(surface.motion.progress > 0 && surface.motion.progress < 1, "closing rolls up")
                root.check(surface.shadowVisibility > 0 && surface.shadowVisibility < 1
                    && shadow.mapToItem(surface, 0, 0).y === shadowTop,
                    "closing fades the anchored shadow instead of sliding it out")
                const shadowOpacity = surface.shadowVisibility
                const progress = surface.motion.progress
                surface.requestedVisible = true
                root.check(surface.motion.progress === progress, "reopening reverses from the current frame")
                root.check(surface.shadowVisibility === shadowOpacity, "shadow fade reverses without resetting")
                events.tryCompare(surface.motion,"transitioning",false,500)
                surface.requestedVisible = false
                events.tryCompare(surface,"presented",false,400)
                root.check(surface.motion.reservedHeight === 0, "closed panel releases its render reservation")
                surface.motion.motionEnabled = false
                surface.requestedVisible = true
                root.check(surface.motion.progress === 1 && !surface.motion.transitioning && surface.shadowVisibility === 1,
                    "disabled motion opens the panel and shadow immediately")
                surface.contentKey = "without motion"
                root.check(surface.motion.progress === 1 && surface.motion.contentOpacity === 1,
                    "content handoff is immediate when motion is disabled")
                surface.contentHeight = 320
                events.wait(1)
                root.check(surface.motion.displayedHeight === 320, "disabled motion resizes immediately")
                tabs.currentIndex = 1
                events.wait(1)
                root.check(surface.motion.contentOpacity === 1 && !surface.motion.transitioning,
                    "tab changes are immediate when panel motion is disabled")
                surface.requestedVisible = false
                root.check(!surface.presented && surface.shadowVisibility === 0,
                    "disabled motion closes the panel and shadow immediately")
                surface.motion.motionEnabled = true
                surface.requestedVisible = true
                events.wait(30)
                surface.motion.motionEnabled = false
                root.check(surface.motion.progress === 1 && !surface.motion.transitioning,
                    "starting a screen share settles an in-flight opening")
                surface.motion.motionEnabled = true
                surface.requestedVisible = false
                events.wait(30)
                surface.motion.motionEnabled = false
                root.check(!surface.presented && !surface.motion.transitioning,
                    "starting a screen share finishes an in-flight closing")
                surface.requestedVisible = true
                surface.continuousGeometry = true
                surface.motion.motionEnabled = true
                surface.contentHeight = 450
                events.wait(1)
                root.check(surface.motion.displayedHeight === 450 && !surface.motion.transitioning,
                    "clipboard layout motion is not eased a second time")
                root.fakeAudio.screencastActive = false
                tween.start()
                behaviorSource.value = 100
                events.wait(35)
                root.check(tweenTarget.value > 0 && tweenTarget.value < 100, "shared animation runs when policy permits")
                root.check(behaviorTarget.value > 0 && behaviorTarget.value < 100, "bound behaviors animate normally")
                tabs.currentIndex = 2
                events.wait(1)
                root.check(surface.motion.contentOpacity < 1, "tab fade starts before a screen share")
                root.fakeAudio.screencastActive = true
                root.check(!UI.MotionPolicy.enabled && !tween.running && tweenTarget.value === 100,
                    "active sharing settles running primitives immediately")
                root.check(behaviorTarget.value === 100, "sharing settles running Behavior animations")
                root.check(surface.motion.contentOpacity === 1, "starting screen sharing completes an active tab fade")
                tabs.currentIndex = 0
                events.wait(1)
                root.check(surface.motion.contentOpacity === 1 && !surface.motion.transitioning,
                    "screen sharing disables subsequent tab fades through the shared policy")
                behaviorSource.value = 200
                root.check(behaviorTarget.value === 200, "disabled Behavior still follows its original binding")
                events.wait(1)
                behaviorSource.value = 300
                root.check(behaviorTarget.value === 300, "temporary snapping preserves the original binding")
                tweenTarget.value = 0; tween.restart()
                root.check(!tween.running && tweenTarget.value === 100,
                    "animations started during sharing complete without motion")
                surface.requestedVisible = false
                root.check(!surface.presented, "global sharing policy also closes panels immediately")
                root.fakeAudio.screencastActive = false
                TooltipService.show(100, resizingTabContent, null, false)
                events.wait(1)
                events.tryCompare(layoutSurface.motion,"transitioning",false,500)
                const shrinkingTabs = events.findChild(layoutKeys.loadedContent, "resizingTabs") as UI.TabBar
                const oldHeight = layoutSurface.motion.displayedHeight
                shrinkingTabs.currentIndex = 0
                root.check(layoutSurface.motion.contentOpacity === 0,
                    "tab replacement is hidden synchronously before the first layout frame")
                // Force the new shorter Column to lay out before queued host
                // geometry runs, reproducing CPU -> Overview's original jump.
                events.grabImage(layoutSurface)
                root.check(layoutKeys.loadedContent.mapToItem(layoutSurface,0,0).y === Theme.tooltipPaddingHeight,
                    "shorter tab content stays at the top while the outgoing frame is still tall")
                events.wait(1)
                events.tryCompare(layoutSurface.motion,"transitioning",false,500)
                root.check(layoutSurface.motion.displayedHeight < oldHeight && layoutSurface.motion.contentOpacity === 1,
                    "shrinking tabs settle at the latest height with content fully visible")
                layoutSurface.requestedVisible = false
                TooltipService.dismiss()
                surface.continuousGeometry = false
                surface.requestedVisible = true
                tweenTarget.value = 0; tween.restart()
                behaviorSource.value = 400
                looping.start()
                events.wait(35)
                const countdownTime = countdown.clockNow
                const countdownProgress = countdown.countdownProgress
                root.fakeConfig.animationsEnabled = false
                root.check(policyVisualizer.rendering && policyShader.animating,
                    "media visualizers remain enabled independently of general UI motion")
                root.check(events.findChild(policyShader, "mediaCavaBandBlend").policyEnabled
                    && events.findChild(policyShader, "mediaCavaTime").policyEnabled,
                    "both shader animators use the visualizer policy instead of the general motion gate")
                root.check(!UI.MotionPolicy.enabled && UI.MotionPolicy.notificationBorderEnabled,
                    "master switch disables general motion and leaves the notification border enabled")
                events.wait(1)
                root.check(!tween.running && tweenTarget.value === 100 && !looping.running
                    && behaviorTarget.value === 400 && !surface.motion.transitioning && surface.motion.progress === 1,
                    "master switch settles panels, finite transitions and bindings, and stops infinite motion")
                events.wait(35)
                root.check(countdown.clockNow > countdownTime && countdown.countdownProgress < countdownProgress,
                    "notification countdown border keeps progressing while UI animations are disabled")
                tabs.currentIndex = 1
                events.wait(1)
                root.check(surface.motion.contentOpacity === 1 && !surface.motion.transitioning,
                    "master switch also disables tab fades")
                surface.requestedVisible = false
                root.check(!surface.presented, "master switch closes panels immediately")
                root.fakeConfig.animateDuringScreenShare = true
                root.fakeAudio.screencastActive = true
                root.check(policyVisualizer.rendering && policyShader.animating,
                    "media visualizers remain enabled during screen sharing")
                root.fakeConfig.mediaVisualizerEnabled = false
                root.check(!UI.MotionPolicy.mediaVisualizerEnabled && !policyVisualizer.rendering && !policyShader.animating,
                    "the visualizer switch stops rendering and shader motion")
                root.fakeConfig.mediaVisualizerEnabled = true
                root.check(policyVisualizer.rendering && policyShader.animating,
                    "reenabling visualizers resumes them during sharing")
                root.check(!UI.MotionPolicy.enabled && UI.MotionPolicy.notificationBorderEnabled,
                    "allowing motion during sharing cannot override the disabled master switch")
                root.fakeConfig.animateDuringScreenShare = false
                const sharingCountdownTime = countdown.clockNow
                events.wait(35)
                root.check(!UI.MotionPolicy.enabled && countdown.clockNow > sharingCountdownTime,
                    "status countdown keeps progressing during sharing with decorative motion disabled")
                const pulsePolicies = ["screenSharePulseEnabled", "micPulseEnabled", "volumePulseEnabled"]
                for (const policy of pulsePolicies) {
                    root.check(UI.MotionPolicy[policy], policy + " survives the master and sharing restrictions")
                    root.fakeConfig[policy] = false
                    root.check(!UI.MotionPolicy[policy] && UI.MotionPolicy.notificationBorderEnabled,
                        policy + " can be disabled independently")
                    root.fakeConfig[policy] = true
                }
                root.fakeConfig.notificationBorderAnimationEnabled = false
                const disabledCountdownTime = countdown.clockNow
                events.wait(35)
                root.check(!UI.MotionPolicy.notificationBorderEnabled && countdown.clockNow === disabledCountdownTime,
                    "notification border has its own animation switch")
                root.fakeConfig.notificationBorderAnimationEnabled = true
                events.wait(35)
                root.check(countdown.clockNow > disabledCountdownTime,
                    "reenabling the border resumes countdown rendering")
                root.fakeAudio.screencastActive = false
                root.fakeConfig.animationsEnabled = true
                tweenTarget.value = 0; tween.restart()
                events.wait(35)
                root.check(UI.MotionPolicy.enabled && tween.running && tweenTarget.value > 0 && tweenTarget.value < 100,
                    "reenabling the master switch restores animation")
                tween.complete()
                console.log(root.failed ? "MOTION FAIL: panel presentation" : "PASS: shared dropdown, roll-up, resize, top-aligned tabs, master switch, independent status indicators, input release and sharing policy")
            } catch (error) { console.error("MOTION FAIL:", error) }
            Qt.quit()
        }
    }
}
