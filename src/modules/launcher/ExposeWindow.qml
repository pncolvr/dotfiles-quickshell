pragma ComponentBehavior: Bound
import QtQuick
import "../../ui" as UI
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../theme"
import "../../services"
import "../../config"

// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    property var capturePanel: contentLoader.item
    property bool contentActive: false
    function synchronizeContent() {
        if (requested || visible) {
            contentActive = true;
            (contentLoader.item as ExposePanel)?.resumePreviews()
        } else {
            // Remove delegate bindings while their models/context still exist.
            // Destroy the surrounding view only after those removals settle.
            (contentLoader.item as ExposePanel)?.releasePreviews()
            Qt.callLater(() => { if (!root.visible) root.contentActive = false })
        }
    }
    property bool hideForCapture: capturePanel?.hideForCapture ?? false
    signal captureHideRequested()
    onCaptureHideRequested: picker.close()
    UI.CaptureOverlay { host: root; requested: root.requested }
    property var picker: PickerService
    LauncherFocusHandler { id: focusHandler; host: root; panel: contentLoader.item; picker: root.picker; ready: root.requested && !!contentLoader.item }
    property var wallpapers: ({})
    readonly property Item previewItem: panel
    property bool animationsEnabled: UI.MotionPolicy.enabled
    property int transitionWorkspace: 0
    property real transitionProgress: 0
    property rect zoomRect: Qt.rect(0, 0, 0, 0)
    // Quickshell's screen metadata is opaque across native module boundaries.
    readonly property var geometryScreen: screen
    property point monitorOrigin: Qt.point(Hyprland.monitorFor(screen)?.lastIpcObject?.x ?? geometryScreen?.x ?? 0,
        Hyprland.monitorFor(screen)?.lastIpcObject?.y ?? geometryScreen?.y ?? 0)
    property var reservedMargins: Hyprland.monitorFor(screen)?.lastIpcObject?.reserved ?? [0, Theme.barHeight, 0, 0]
    readonly property rect desktopRect: Qt.rect(reservedMargins[0], reservedMargins[1],
        Math.max(1, width - reservedMargins[0] - reservedMargins[2]),
        Math.max(1, height - reservedMargins[1] - reservedMargins[3]))
    // Fit inside the usable desktop, preserving the bar and the preview's aspect ratio.
    readonly property real zoomFactor: zoomRect.width > 0 && zoomRect.height > 0
        ? Math.max(1, Math.min(desktopRect.width / zoomRect.width, desktopRect.height / zoomRect.height)) : 1
    readonly property real cameraScale: zoomFactor + (1 - zoomFactor) * transitionProgress
    readonly property real cameraX: (desktopRect.x + desktopRect.width / 2
        - (zoomRect.x + zoomRect.width / 2) * zoomFactor) * (1 - transitionProgress)
    readonly property real cameraY: (desktopRect.y + desktopRect.height / 2
        - (zoomRect.y + zoomRect.height / 2) * zoomFactor) * (1 - transitionProgress)
    function updateZoomRect() {
        const view = contentLoader.item as ExposePanel
        const rect = view?.workspacePreviewRect(transitionWorkspace)
        zoomRect = rect ? Qt.rect(contentLoader.x + rect.x, contentLoader.y + rect.y, rect.width, rect.height)
            : Qt.rect(0, 0, width, height)
    }
    UI.MotionAnimation {
        id: transitionAnimation
        target: root
        property: "transitionProgress"
        animationDuration: Theme.exposeAnimationDuration
        easing.type: root.requested ? Easing.OutCubic : Easing.InCubic
    }
    function updateTransition() {
        transitionAnimation.stop()
        updateZoomRect()
        if (animationsEnabled) {
            transitionAnimation.to = requested ? 1 : 0
            transitionAnimation.restart()
        } else transitionProgress = requested ? 1 : 0
    }
    onAnimationsEnabledChanged: updateTransition()
    Timer {
        id: prepareTransition
        interval: 16
        onTriggered: if (root.requested) root.updateTransition()
    }
    Component.onCompleted: {
        synchronizeContent()
        if (requested && animationsEnabled) prepareTransition.restart(); else updateTransition()
    }
    readonly property bool requested: picker.visible && picker.layout === "expose" && !!picker.targetScreen
    readonly property bool requestedVisible: requested
    screen: Quickshell.screens.includes(picker.targetScreen) ? picker.targetScreen : Quickshell.screens[0] ?? null
    visible: requested || (picker.layout === "expose" && transitionProgress > 0)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: Config.pickerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: focusHandler.keyboardFocusMode
    // Initialize native capture buffers before the lazy grid attaches to the scene.
    UI.ScaledScreencopyView { visible: false; captureSource: null }
    function imageUrl(path) { return path ? "file://" + path.split("/").map(part => encodeURIComponent(part)).join("/") : "" }
    function applyWallpapers(text) {
        try {
            const report = JSON.parse(text)
            const result = {}
            for (const outputs of Object.values(report)) {
                for (const output of outputs) if (output.displaying?.image) result[output.name] = output.displaying.image
            }
            wallpapers = result
        } catch (_) { wallpapers = ({}) }
    }
    onRequestedChanged: {
        synchronizeContent()
        if (requested) {
            transitionWorkspace = picker.exposeReturnWorkspace
        } else if (picker.exposeCloseTarget) {
            transitionWorkspace = picker.exposeCloseTarget.workspaceId
            // Let Hyprland switch beneath the opaque overview while its own zoom closes.
            // Window focus remains deferred until this layer has unmapped.
            picker.prepareExposeClose()
        }
        prepareTransition.stop()
        if (requested && animationsEnabled) prepareTransition.restart()
        else updateTransition()
    }
    onVisibleChanged: {
        synchronizeContent()
        if (visible) {
            Hyprland.refreshMonitors()
            Hyprland.refreshToplevels()
            wallpaperQuery.running = true
        } else {
            wallpaperQuery.running = false
            picker.finishExposeClose()
        }
    }
    Process {
        id: wallpaperQuery
        command: Config.exposeWallpaperCommand
        stdout: StdioCollector { id: wallpaperOutput; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => { if (root.visible) root.applyWallpapers(exitCode === 0 && exitStatus === 0 ? wallpaperOutput.text : "{}") }
        // qmllint enable signal-handler-parameters
    }
    Rectangle {
        id: panel
        anchors.fill: parent
        color: Theme.background
        clip: true
        // Blend capture startup while the whole overview zooms out from its target.
        // Keep workspace closing visible until its miniature reaches desktop size.
        opacity: root.requested ? Math.min(1, root.transitionProgress * 5) : 1
        UI.ScaledImage {
            anchors.fill: parent
            source: root.imageUrl(root.wallpapers[root.geometryScreen?.name])
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, Theme.exposeBackdropOpacity * root.transitionProgress)
            MouseArea { anchors.fill: parent; onClicked: root.picker.close() }
        }
        Item {
            id: camera
            objectName: "exposeCamera"
            anchors.fill: parent
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(root.cameraScale, 0, 0, root.cameraX,
                    0, root.cameraScale, 0, root.cameraY, 0, 0, 1, 0, 0, 0, 0, 1)
            }
            Loader {
                id: contentLoader
                anchors.fill: parent
                enabled: root.requested
                anchors.margins: Theme.exposeSpacing * 2
                anchors.topMargin: Theme.exposeSpacing
                anchors.bottomMargin: Theme.exposeSpacing
                active: root.contentActive
                sourceComponent: ExposePanel {
                    picker: root.picker
                    transitionProgress: root.transitionProgress
                    animationsEnabled: root.animationsEnabled
                    desktopGeometry: Qt.rect(root.monitorOrigin.x + root.desktopRect.x,
                        root.monitorOrigin.y + root.desktopRect.y, root.desktopRect.width, root.desktopRect.height)
                }
            }
        }
    }
}
