import QtQuick
import QtQuick.Window
import QtQuick.Effects
import "../../../theme"
import "../../../theme/ui" as UI

Item {
    id: root
    property url artworkSource: ""
    UI.ScaledImage {
        id: artwork
        anchors.fill: parent
        source: root.artworkSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
        visible: false
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: Math.max(0, Theme.audioDeviceRadius - 1)
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
        visible: artwork.status === Image.Ready
        source: artwork
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: Theme.mediaArtworkBlurRadius
        blur: 1
        colorization: Theme.mediaArtworkBackgroundTint
        colorizationColor: Theme.alternateBackground
        opacity: Theme.mediaArtworkBackgroundOpacity
        maskEnabled: true
        maskSource: maskTexture
    }
}
