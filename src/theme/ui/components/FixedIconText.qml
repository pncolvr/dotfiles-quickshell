import QtQuick
import "../"
import "../../"

Item {
    id: root
    property alias text: glyph.text
    property alias font: glyph.font
    property alias color: glyph.color
    property alias pulsing: glyph.pulsing
    property alias animationEnabled: glyph.animationEnabled
    property alias baseColor: glyph.baseColor
    property alias pulseColor: glyph.pulseColor
    property bool centerVertical: true
    property bool centerGlyphVertically: false
    property real slotWidth: Theme.iconButtonWidth
    implicitWidth: slotWidth
    implicitHeight: glyph.implicitHeight
    anchors.verticalCenter: centerVertical ? parent.verticalCenter : undefined

    TextMetrics {
        id: glyphMetrics
        font: glyph.font
        text: glyph.text
    }

    PulseIconText {
        id: glyph
        width: parent.width
        height: parent.height
        // Opt in to centering visible ink instead of the font's line box.
        y: root.centerGlyphVertically ? (root.height - glyphMetrics.tightBoundingRect.height) / 2
            - baselineOffset - glyphMetrics.tightBoundingRect.y : 0
        centerVertical: false
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
