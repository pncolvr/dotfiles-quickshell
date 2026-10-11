import QtQuick
import QtQuick.Controls as QC
import "../../../theme"
import "../../../theme/ui" as UI

QC.Button {
    id: root
    property string glyph: ""
    property string label: ""
    property string hint: ""
    property bool highlightedDevice: false
    readonly property color foreground: highlightedDevice ? Theme.accent : Theme.text
    implicitWidth: contents.implicitWidth + Theme.audioButtonPadding * 2
    implicitHeight: Theme.audioButtonHeight
    padding: Theme.audioButtonPadding
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5
    Accessible.name: hint || label

    background: Rectangle {
        radius: Theme.iconButtonRadius
        color: root.down ? Theme.empty : root.hovered ? Qt.lighter(Theme.alternateBackground, 1.5) : Theme.alternateBackground
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.accent
    }
    contentItem: Row {
        id: contents
        spacing: root.label ? Theme.audioSpacing : 0
        UI.FixedIconText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            visible: text.length > 0
            color: root.foreground
            font.pixelSize: Theme.fontSize
            font.bold: false
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            visible: text.length > 0
            color: root.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: Theme.fontBold
        }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    UI.HoverTooltip {
        hoverTarget: root
        text: root.hint
    }
}
