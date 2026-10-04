import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI

UI.ActionButton {
    id: root
    implicitWidth: Math.max(Theme.actionButtonWidth, metrics.width + 24 + (glyph ? 24 : 0))
    TextMetrics { id: metrics; text: root.label; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.bold: true }
}
