pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../theme"
import "../../theme/ui" as UI

Rectangle {
    id: root
    required property var client
    readonly property var toplevel: Hyprland.toplevels.values.find(window => window.address.replace(/^0x/, "").toLowerCase() === client.address.replace(/^0x/, "").toLowerCase()) ?? null
    readonly property var captureSource: toplevel?.wayland ?? null
    readonly property bool hasContent: (capture.item as ScreencopyView)?.hasContent ?? false
    // A different window gets a new capture view and scene-graph texture.
    onCaptureSourceChanged: {
        if (!capture) return
        capture.active = false
        capture.active = !!captureSource
    }
    readonly property string icon: DesktopEntries.byId(client.class)?.icon || DesktopEntries.byId(client.initialClass)?.icon || client.class || ""
    color: Theme.background
    clip: true
    radius: Theme.iconButtonRadius
    Loader {
        id: capture
        anchors.centerIn: parent
        active: !!root.captureSource
        sourceComponent: ScreencopyView {
            objectName: "exposeCapture"
            captureSource: root.captureSource
            live: true
            // Screencopy's native texture uses linear filtering without mipmaps.
            // Preserve source pixels in the layer before generating lower-resolution levels.
            layer.enabled: hasContent && width > 0 && height > 0
                && (sourceSize.width > width * 2 || sourceSize.height > height * 2)
            layer.textureSize: sourceSize
            layer.mipmap: true
            layer.smooth: true
            // Fit the actual buffer through resize and output-scale changes.
            readonly property real aspectRatio: sourceSize.width > 0 && sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1
            width: Math.min(root.width, root.height * aspectRatio)
            height: width / aspectRatio
        }
    }
    Image {
        id: fallback
        anchors.centerIn: parent
        width: Math.min(48, parent.width * 0.3)
        height: width
        source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
        visible: !root.hasContent && status === Image.Ready
        asynchronous: true
        fillMode: Image.PreserveAspectFit
    }
    UI.IconText {
        anchors.centerIn: parent
        visible: !root.hasContent && !fallback.visible
        text: Theme.exposeIcon
        color: Theme.inactive
        font.pixelSize: Math.min(32, root.height * 0.4)
    }
}
