pragma ComponentBehavior: Bound
import QtQuick
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
    property var picker: PickerService
    property var wallpapers: ({})
    readonly property Item previewItem: panel
    property bool animationsEnabled: Config.exposeAnimateDuringScreenShare || !AudioService.screencastActive
    property int transitionWorkspace: 0
    property string transitionAddress: ""
    property real transitionProgress: 0
    property rect zoomRect: Qt.rect(0, 0, 0, 0)
    property string zoomTarget: ""
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
    function chooseZoomTarget() {
        const view = contentLoader.item as ExposePanel
        let rect = view?.windowPreviewRect(transitionAddress)
        zoomTarget = rect ? "window" : "workspace"
        if (!rect) rect = view?.workspacePreviewRect(transitionWorkspace)
        zoomRect = rect ? Qt.rect(contentLoader.x + rect.x, contentLoader.y + rect.y, rect.width, rect.height)
            : Qt.rect(0, 0, width, height)
    }
    NumberAnimation {
        id: transitionAnimation
        target: root
        property: "transitionProgress"
        duration: Theme.exposeAnimationDuration
        easing.type: root.requested ? Easing.OutCubic : Easing.InCubic
    }
    function updateTransition() {
        transitionAnimation.stop()
        chooseZoomTarget()
        if (animationsEnabled) {
            transitionAnimation.to = requested ? 1 : 0
            transitionAnimation.restart()
        } else transitionProgress = requested ? 1 : 0
    }
    onAnimationsEnabledChanged: updateTransition()
    onTransitionProgressChanged: if (requested && transitionProgress === 1) {
        Qt.callLater(() => (contentLoader.item as ExposePanel)?.focusSearch())
    }
    Timer {
        id: prepareTransition
        interval: 16
        onTriggered: if (root.requested) root.updateTransition()
    }
    Component.onCompleted: if (requested && animationsEnabled) prepareTransition.restart(); else updateTransition()
    readonly property bool requested: picker.visible && picker.layout === "expose" && !!picker.targetScreen
    screen: Quickshell.screens.includes(picker.targetScreen) ? picker.targetScreen : Quickshell.screens[0] ?? null
    visible: requested || (picker.layout === "expose" && transitionProgress > 0)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: Config.pickerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: requested ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Initialize native capture buffers before the lazy grid attaches to the scene.
    ScreencopyView { visible: false; captureSource: null }
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
    HyprlandFocusGrab {
        id: grab
        windows: [root]
        active: root.requested && root.transitionProgress === 1
        onCleared: if (root.requested && root.transitionProgress === 1) root.picker.close()
    }
    onRequestedChanged: {
        if (requested) {
            transitionWorkspace = Hyprland.focusedWorkspace?.id ?? picker.exposeWorkspace
            transitionAddress = picker.currentItem?.id ?? ""
        } else if (picker.exposeCloseTarget) {
            transitionWorkspace = picker.exposeCloseTarget.workspaceId
            transitionAddress = picker.exposeCloseTarget.id
        }
        prepareTransition.stop()
        if (requested && animationsEnabled) prepareTransition.restart()
        else updateTransition()
    }
    onVisibleChanged: {
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
        opacity: !root.requested && root.picker.exposeCloseTarget
            ? 1 : Math.min(1, root.transitionProgress * 5)
        Image {
            anchors.fill: parent
            source: root.imageUrl(root.wallpapers[root.screen?.name])
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
                active: root.visible
                sourceComponent: ExposePanel {
                    picker: root.picker
                    transitionProgress: root.transitionProgress
                    captureAddress: root.zoomTarget === "window" ? root.transitionAddress : ""
                }
            }
        }
    }
}
