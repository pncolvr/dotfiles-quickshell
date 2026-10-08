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
    screen: Quickshell.screens.includes(picker.targetScreen) ? picker.targetScreen : Quickshell.screens[0] ?? null
    visible: picker.visible && picker.layout === "expose" && !!picker.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: Config.pickerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
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
    HyprlandFocusGrab { id: grab; windows: [root]; onCleared: if (root.visible) root.picker.close() }
    onVisibleChanged: {
        grab.active = visible
        if (visible) {
            Hyprland.refreshToplevels()
            wallpaperQuery.running = true
        } else wallpaperQuery.running = false
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
        Image {
            anchors.fill: parent
            source: root.imageUrl(root.wallpapers[root.screen?.name])
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, Theme.exposeBackdropOpacity)
            MouseArea { anchors.fill: parent; onClicked: root.picker.close() }
        }
        Loader {
            anchors.fill: parent
            anchors.margins: Theme.exposeSpacing * 2
            active: root.visible
            sourceComponent: ExposePanel { picker: root.picker }
        }
    }
}
