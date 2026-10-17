import QtQuick
import "../../../theme"
import "../../../ui" as UI

UI.ActionButton {
    id: root
    implicitWidth: label.length ? Math.max(Theme.actionButtonWidth, metrics.width + 24 + (glyph ? 24 : 0)) : Theme.actionButtonWidth
    TextMetrics { id: metrics; text: root.label; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.bold: true }
}
