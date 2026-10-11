import QtQuick
import "../"
import "../../"

Item {
    id: root
    property alias text: glyph.text
    property alias font: glyph.font
    property alias color: glyph.color
    property alias pulsing: glyph.pulsing
    property alias baseColor: glyph.baseColor
    property alias pulseColor: glyph.pulseColor
    property bool centerVertical: true
    property real slotWidth: Theme.iconButtonWidth
    implicitWidth: slotWidth
    implicitHeight: glyph.implicitHeight
    anchors.verticalCenter: centerVertical ? parent.verticalCenter : undefined

    PulseIconText {
        id: glyph
        anchors.fill: parent
        centerVertical: false
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
