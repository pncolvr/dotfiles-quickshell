import QtQuick
import "../"
import "../../"

TooltipArea {
    id: root
    implicitWidth: Theme.iconButtonWidth
    implicitHeight: Theme.iconButtonHeight
    cursorShape: Qt.PointingHandCursor

    property alias font: inner.font
    property alias text: inner.text
    property alias iconColor: inner.iconColor
    property alias hovered: root.containsMouse
    property alias centerVertical: inner.centerVertical
    readonly property real glyphWidth: inner.glyphWidth

    Icon {
        id: inner
        width: root.width
        height: Theme.iconButtonHeight
        radius: Theme.iconButtonRadius
        color: root.hovered ? Theme.accent : "transparent"
    }
}