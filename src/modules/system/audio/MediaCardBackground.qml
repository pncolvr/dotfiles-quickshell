import QtQuick
import QtQuick.Effects
import "../../../theme"
import "../../../ui" as UI

Item {
    id: root
    property url artworkSource: ""
    property real radius: Math.max(0, Theme.audioDeviceRadius - 1)
    // Cached fullscreen backgrounds must capture the final crop, not the frame
    // visible between decoding the source and completing its analysis.
    readonly property bool ready: artwork.status === Image.Ready && !!artwork.analysis
    Item {
        id: artworkFrame
        anchors.fill: parent
        // Capture the composed child, including its layer's circular mask.
        // Capturing CroppedImage directly skips its sibling layer-effect proxy.
        UI.CroppedImage {
            id: artwork
            anchors.fill: parent
            source: root.artworkSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
    UI.ScaledTexture {
        id: artworkTexture
        anchors.fill: parent
        sourceItem: artworkFrame
        hideSource: true
        visible: false
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        color: "white"
        visible: false
    }
    UI.ScaledTexture {
        id: maskTexture
        sourceItem: mask
        hideSource: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        visible: root.ready
        source: artworkTexture
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: Theme.mediaArtworkBlurRadius
        blur: 1
        colorization: Theme.mediaArtworkBackgroundTint
        colorizationColor: Theme.alternateBackground
        opacity: Theme.mediaArtworkBackgroundOpacity
        maskEnabled: root.radius > 0
        maskSource: maskTexture
    }
}
