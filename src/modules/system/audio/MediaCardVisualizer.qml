pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../../../theme"
import "../../../ui" as UI

Loader {
    id: root
    required property ShaderEffectSource textureSource
    property real radius: Math.max(0, Theme.audioDeviceRadius - 1)
    active: false
    enabled: false
    sourceComponent: Component {
        Item {
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
                source: root.textureSource
                autoPaddingEnabled: false
                maskEnabled: true
                maskSource: maskTexture
            }
        }
    }
}
