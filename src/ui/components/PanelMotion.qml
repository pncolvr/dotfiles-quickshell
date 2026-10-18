pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"

// Presentation outlives a close request; interaction never waits for this motion.
Item {
    id: root
    visible: false
    property bool requested: false
    property bool motionEnabled: true
    readonly property bool motionAllowed: motionEnabled && MotionPolicy.enabled
    property bool continuousGeometry: false
    property bool centeredResize: false
    property var contentKey: null
    property real contentOpacity: 1
    property real targetX: 0
    property real targetWidth: 0
    property real targetHeight: 0
    property real reserveHeight: 0
    property var targetScreen: null
    property var displayedScreen: null
    property real displayedX: 0
    property real displayedWidth: 0
    property real displayedHeight: 0
    property real layoutWidth: 0
    property real layoutHeight: 0
    property real reservedHeight: 0
    property real progress: 0
    property bool preparing: false
    property bool geometryQueued: false
    readonly property bool presented: requested || progress > 0 || reveal.running
    readonly property bool transitioning: preparing || reveal.running || resize.running || contentFade.running
    readonly property real fraction: Math.max(0, Math.min(1, progress))
    readonly property real offsetY: -(displayedHeight + Theme.tooltipShadowBlurRadius) * (1 - fraction)
    readonly property rect targetGeometry: Qt.rect(targetX, 0, Math.max(0,targetWidth), Math.max(0,targetHeight))

    function snapGeometry() {
        resize.stop()
        contentFade.stop()
        contentOpacity = 1
        displayedX = targetX
        displayedWidth = Math.max(0,targetWidth)
        displayedHeight = Math.max(0,targetHeight)
        layoutWidth = displayedWidth
        layoutHeight = displayedHeight
        reservedHeight = Math.max(displayedHeight, reserveHeight)
    }
    // Content can change without changing the frame's dimensions (tab switches).
    // Use the same fade for both cases so their animations never multiply.
    function fadeContent() {
        contentFade.stop()
        if (!requested || !motionAllowed) { contentOpacity = 1; return }
        contentOpacity = 0
        contentFade.start()
    }
    function updateGeometry() {
        geometryQueued = false
        if (!requested) return
        layoutWidth = Math.max(0,targetWidth)
        layoutHeight = Math.max(0,targetHeight)
        if (!motionAllowed || preparing || continuousGeometry || progress === 0) { snapGeometry(); return }
        // Centered pickers resize both edges together. Other module anchors move
        // immediately, preserving their dropdown placement behavior.
        if (!centeredResize || (displayedWidth === layoutWidth && displayedHeight === layoutHeight)) displayedX = targetX
        if (displayedWidth === layoutWidth && displayedHeight === layoutHeight) return
        resize.stop()
        reservedHeight = Math.max(displayedHeight, layoutHeight, reserveHeight)
        fadeContent()
        moveX.to = targetX
        growWidth.to = layoutWidth
        growHeight.to = layoutHeight
        resize.start()
    }
    function changeContent() {
        if (!requested) return
        // Coalesce the new Loader's geometry before revealing it at its own anchor.
        reveal.stop()
        progress = 0
        transition()
    }
    function queueGeometry() {
        if (geometryQueued) return
        geometryQueued = true
        Qt.callLater(root.updateGeometry)
    }
    function settleReservation() {
        if (requested && !resize.running) reservedHeight = Math.max(displayedHeight, reserveHeight)
        else if (!presented) reservedHeight = 0
    }
    function transition() {
        const wasPresented = progress > 0
        reveal.stop()
        preparing = false
        switch (true) {
        case motionAllowed && requested:
            displayedScreen = targetScreen
            preparing = !wasPresented
            if (preparing) snapGeometry()
            // Let a lazy loader publish its size before the first animated frame.
            Qt.callLater(() => {
                if (!root.requested || !root.motionAllowed) return
                root.updateGeometry()
                root.preparing = false
                root.animateTo(1)
            })
            return
        case motionAllowed:
            contentFade.stop()
            resize.stop()
            animateTo(0)
            return
        case requested:
            displayedScreen = targetScreen
            snapGeometry()
            progress = 1
            break
        default:
            contentFade.stop()
            resize.stop()
            progress = 0
        }
        settleReservation()
    }
    function animateTo(value) {
        if (progress === value) { settleReservation(); return }
        reveal.to = value
        let duration
        switch (value) {
        case 1:
            duration = Theme.panelOpenDuration
            reveal.easing.type = Easing.OutCubic
            break
        default:
            duration = Theme.panelCloseDuration
            reveal.easing.type = Easing.InCubic
        }
        reveal.animationDuration = Math.max(1, Math.round(Math.abs(value - progress) * duration))
        reveal.start()
    }
    onPresentedChanged: if (!presented) reservedHeight = 0
    onRequestedChanged: transition()
    onContentKeyChanged: changeContent()
    onTargetGeometryChanged: queueGeometry()
    onReserveHeightChanged: if (requested) reservedHeight = Math.max(reservedHeight, reserveHeight)
    onContinuousGeometryChanged: queueGeometry()
    onTargetScreenChanged: if (requested) displayedScreen = targetScreen
    onMotionAllowedChanged: if (!motionAllowed) transition()
    Component.onCompleted: transition()
    MotionAnimation {
        id: reveal
        objectName: "panelReveal"
        target: root
        property: "progress"
        onStopped: root.settleReservation()
    }
    MotionAnimation {
        id: contentFade
        target: root
        property: "contentOpacity"
        to: 1
        animationDuration: Theme.panelResizeDuration
        easing.type: Easing.OutCubic
    }
    ParallelAnimation {
        id: resize
        objectName: "panelResize"
        MotionAnimation { id: moveX; target: root; property: "displayedX"; animationDuration: Theme.panelResizeDuration; easing.type: Easing.OutCubic }
        MotionAnimation { id: growWidth; target: root; property: "displayedWidth"; animationDuration: Theme.panelResizeDuration; easing.type: Easing.OutCubic }
        MotionAnimation { id: growHeight; target: root; property: "displayedHeight"; animationDuration: Theme.panelResizeDuration; easing.type: Easing.OutCubic }
        onStopped: root.settleReservation()
    }
}
