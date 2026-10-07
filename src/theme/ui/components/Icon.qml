import QtQuick
import "../"

Rectangle {
    id: root
    property alias text: icon.text
    property alias iconColor: icon.color
    property bool centerVertical: true

    IconText {
        id: icon
        centerVertical: false
        // Center the visible glyph rather than its advance width and line box.
        x: (root.width - iconMetrics.tightBoundingRect.width) / 2 - iconMetrics.tightBoundingRect.x
        y: root.centerVertical ? (root.height - iconMetrics.tightBoundingRect.height) / 2
            - baselineOffset - iconMetrics.tightBoundingRect.y : 0
    }

    TextMetrics {
        id: iconMetrics
        font: icon.font
        text: icon.text
    }
}
