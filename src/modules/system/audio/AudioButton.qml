import QtQuick
import "../../../theme"
import "../../../ui" as UI

UI.ActionButton {
    id: root
    property int glyphSize: Theme.fontSize
    property bool highlightedDevice: false
    foreground: highlightedDevice ? Theme.accent : Theme.text
    implicitWidth: contents.implicitWidth + Theme.audioButtonPadding * 2
    implicitHeight: Theme.audioButtonHeight
    padding: Theme.audioButtonPadding
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5

    background: Rectangle {
        radius: Theme.iconButtonRadius
        color: root.down ? Theme.empty : root.hovered ? Qt.lighter(Theme.alternateBackground, 1.5) : Theme.alternateBackground
        border.width: root.keyboardFocusVisible ? 1 : 0
        border.color: Theme.accent
    }
    contentItem: Item {
        implicitWidth: contents.implicitWidth
        implicitHeight: contents.implicitHeight
        Row {
            id: contents
            anchors.centerIn: parent
            spacing: root.label ? Theme.audioSpacing : 0
            UI.FixedIconText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyph
                visible: text.length > 0
                color: root.foreground
                font.pixelSize: root.glyphSize
                font.bold: false
            }
            UI.TextBase {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                visible: text.length > 0
                color: root.foreground
            }
        }
    }
}
