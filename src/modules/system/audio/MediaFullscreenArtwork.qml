pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import "../../../config"
import "../../../theme"
import "../../../ui" as UI

// Static decoration for fullscreen only. The original artwork stays sharp;
// playback and visualizer lifecycles remain owned by the fullscreen view.
Item {
    id: root
    objectName: "mediaFullscreenArtwork"
    property string style: Config.mediaFullscreenArtworkStyle
    readonly property string resolvedStyle: ["cassette", "cd", "disc"].includes(style) ? style : "plain"
    property alias source: artwork.source
    property url fallbackSource: ""
    property string title: ""
    readonly property int status: artwork.status
    readonly property rect printRect: resolvedStyle === "cassette"
        ? Qt.rect(width * 0.065, height * 0.095, width * 0.87, height * 0.68)
        : resolvedStyle === "cd" ? Qt.rect(width * 0.115, (height - width * 0.85) / 2, width * 0.85, width * 0.85)
        : resolvedStyle === "disc" ? Qt.rect(width * 0.016, height * 0.016, width * 0.968, height * 0.968)
        : Qt.rect(0, 0, width, height)
    implicitHeight: width * (resolvedStyle === "cassette" ? 0.64 : resolvedStyle === "cd" ? 0.89 : 1)
    layer.enabled: resolvedStyle === "disc"
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)),
        Math.max(1, Math.ceil(height * Screen.devicePixelRatio)))
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: discMaskTexture
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        autoPaddingEnabled: false
    }
    // A thick circular border gives the mask both its outside edge and a
    // genuinely transparent spindle hole. Rasterize at device resolution.
    Rectangle {
        id: discMask
        objectName: "mediaDiscMask"
        anchors.fill: parent
        visible: root.resolvedStyle === "disc"
        color: "transparent"
        radius: width / 2
        border.width: width * 0.435
        border.color: "white"
        antialiasing: true
    }
    UI.ScaledTexture {
        id: discMaskTexture
        sourceItem: root.resolvedStyle === "disc" ? discMask : null
        textureSize: root.layer.textureSize
        hideSource: true
        visible: false
    }
    Gradient {
        id: discMetal
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "#6f7c86" }
        GradientStop { position: 0.22; color: "#dce8e8" }
        GradientStop { position: 0.46; color: "#9eabb4" }
        GradientStop { position: 0.68; color: "#f2e7ee" }
        GradientStop { position: 1; color: "#7b8992" }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.resolvedStyle === "disc" ? width / 2
            : root.resolvedStyle === "cassette" ? root.width * 0.035 : Theme.audioDeviceRadius
        gradient: root.resolvedStyle === "disc" ? discMetal : null
        antialiasing: true
        color: root.resolvedStyle === "cassette" ? "#24272a"
            : root.resolvedStyle === "cd" ? "#34383b"
            : artwork.status === Image.Ready ? "transparent" : Theme.background
        border.width: root.resolvedStyle === "plain" ? 0 : Math.max(1, root.width * 0.005)
        border.color: root.resolvedStyle === "cassette" ? "#555b5d" : "#929b9d"
    }
    Rectangle {
        x: root.printRect.x
        y: root.printRect.y
        width: root.printRect.width
        height: root.printRect.height
        radius: root.resolvedStyle === "disc" ? width / 2 : 0
        antialiasing: root.resolvedStyle === "disc"
        color: root.resolvedStyle === "cassette" ? "#e8dfcd"
            : root.resolvedStyle === "plain" && artwork.status === Image.Ready ? "transparent" : Theme.background
        UI.CroppedImage {
            id: artwork
            objectName: "mediaArtwork"
            anchors.fill: parent
            asynchronous: true
            circular: root.resolvedStyle === "disc"
            fillMode: root.resolvedStyle === "plain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        }
        UI.ScaledImage {
            id: fallback
            objectName: "mediaFullscreenArtworkFallback"
            anchors.centerIn: parent
            width: parent.width * 0.22
            height: width
            source: root.fallbackSource
            visible: artwork.status !== Image.Ready
        }
        UI.IconText {
            anchors.centerIn: parent
            text: Theme.mediaIcon
            font.pixelSize: root.width * 0.18
            color: Theme.accent
            visible: artwork.status !== Image.Ready && fallback.status !== Image.Ready
        }
    }
    Item {
        objectName: "mediaDiscDecoration"
        anchors.fill: parent
        visible: root.resolvedStyle === "disc"
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.28
            height: width
            radius: width / 2
            antialiasing: true
            gradient: discMetal
            border.width: Math.max(1, root.width * 0.003)
            border.color: "#d4dfe3"
            Rectangle {
                anchors.centerIn: parent
                width: root.width * 0.19
                height: width
                radius: width / 2
                antialiasing: true
                color: "#a6c6cbd0"
                border.width: Math.max(1, root.width * 0.004)
                border.color: "#84939f"
            }
        }
    }
    // The reels and printed title sit on the label rather than in a separate
    // frame beside it. No timers or additional image decodes are needed.
    Item {
        objectName: "mediaCassetteDecoration"
        anchors.fill: parent
        visible: root.resolvedStyle === "cassette"
        Rectangle {
            x: root.printRect.x
            y: root.printRect.y
            width: root.printRect.width
            height: root.height * 0.17
            color: "#e8dfcd"
            UI.Text {
                objectName: "mediaCassetteTitle"
                anchors.fill: parent
                anchors.leftMargin: root.width * 0.025
                anchors.rightMargin: root.width * 0.025
                verticalAlignment: Text.AlignVCenter
                centerVertical: false
                font.pixelSize: root.width * 0.033
                text: root.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: "#282725"
            }
        }
        Rectangle {
            id: tapeWindow
            objectName: "mediaCassetteReels"
            x: root.width * 0.185
            y: root.height * 0.39
            width: root.width * 0.63
            height: root.height * 0.245
            radius: height / 2
            antialiasing: true
            color: "#141719"
            border.width: Math.max(1, root.width * 0.006)
            border.color: "#666a65"
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.62
                height: parent.height * 0.19
                color: "#5c4736"
            }
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    x: index === 0 ? parent.height * 0.14 : parent.width - width - parent.height * 0.14
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height * 0.76
                    height: width
                    radius: width / 2
                    antialiasing: true
                    color: "#c9c6b8"
                    border.width: width * 0.12
                    border.color: "#746454"
                    Repeater {
                        model: 6
                        Rectangle {
                            required property int index
                            anchors.centerIn: parent
                            width: parent.width * 0.13
                            height: parent.height * 0.69
                            radius: width / 2
                            rotation: index * 60
                            color: "#24272a"
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.34
                        height: width
                        radius: width / 2
                        antialiasing: true
                        color: "#141719"
                    }
                }
            }
        }
        Rectangle {
            x: root.width * 0.20
            y: root.height * 0.84
            width: root.width * 0.60
            height: root.height * 0.13
            radius: height * 0.3
            color: "#191c1e"
            border.width: 1
            border.color: "#353a3c"
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    x: parent.width * (index === 0 ? 0.14 : 0.80)
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.width * 0.034
                    height: width
                    radius: width / 2
                    antialiasing: true
                    color: "#090b0c"
                }
            }
        }
        Repeater {
            model: 4
            Rectangle {
                required property int index
                x: root.width * (index % 2 === 0 ? 0.025 : 0.945)
                y: root.height * (index < 2 ? 0.035 : 0.91)
                width: root.width * 0.03
                height: width
                radius: width / 2
                antialiasing: true
                color: "#878d89"
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.65
                    height: Math.max(1, parent.width * 0.11)
                    rotation: 30
                    color: "#303638"
                }
            }
        }
    }
    Item {
        objectName: "mediaCdDecoration"
        anchors.fill: parent
        visible: root.resolvedStyle === "cd"
        Rectangle {
            x: root.width * 0.025
            y: root.height * 0.025
            width: root.width * 0.075
            height: root.height * 0.95
            color: "#1a1d1f"
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    x: parent.width * (index + 1) / 7
                    y: parent.height * 0.02
                    width: 1
                    height: parent.height * 0.96
                    color: "#62696a"
                    opacity: 0.65
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: root.width * 0.01
            antialiasing: true
            color: "transparent"
            border.width: Math.max(1, root.width * 0.007)
            border.color: "#a4aeaf"
        }
        Rectangle {
            x: root.width * 0.115
            y: root.height * 0.035
            width: Math.max(1, root.width * 0.006)
            height: root.height * 0.93
            color: "#b6c3c2"
            opacity: 0.55
        }
        Repeater {
            model: 2
            Rectangle {
                required property int index
                x: root.width * 0.965
                y: root.height * (index === 0 ? 0.09 : 0.80)
                width: root.width * 0.02
                height: root.height * 0.10
                color: "#a4aeaf"
                opacity: 0.55
            }
        }
    }
}
