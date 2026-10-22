pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"

Button {
    id: root
    implicitWidth: Theme.iconButtonWidth
    implicitHeight: Theme.iconButtonHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    focusPolicy: Qt.NoFocus
    padding: 0
    fillColor: "transparent"
    property color iconColor: Theme.text
    property bool centerVertical: true
    readonly property real glyphWidth: inner.glyphWidth
    font.family: Theme.fontFamilyIcons
    font.pixelSize: Theme.fontSize
    contentItem: Icon {
        id: inner
        text: root.text
        font: root.font
        iconColor: root.iconColor
        centerVertical: root.centerVertical
        color: "transparent"
    }
}
