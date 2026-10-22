import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import ".." as UI

UI.Button {
    id: root
    property string glyph: ""
    property string label: ""
    property string hint: ""
    property string keyAction: ""
    property string hintAction: keyAction
    readonly property string shortcutHint: hintAction ? UI.Keybinds.hint(hint || label,hintAction) : hint

    implicitWidth: label.length ? Math.max(Theme.actionButtonWidth, implicitContentWidth) : Theme.actionButtonWidth
    implicitHeight: Theme.controlHeight
    padding: 0
    Accessible.name: shortcutHint || label
    UI.PanelShortcut { owner: root; action: root.keyAction; onActivated: root.clicked() }
    contentItem: Item {
        readonly property bool adaptiveContrastExcluded: true
        implicitWidth: root.label.length > 0
            ? codeLabel.implicitWidth + (icon.implicitWidth + Theme.controlSpacing + Theme.controlFieldPadding) * 2
            : icon.implicitWidth + Theme.controlFieldPadding * 2
        implicitHeight: Math.max(icon.implicitHeight, root.label.length > 0 ? codeLabel.implicitHeight : 0)

        UI.TextBase {
            id: codeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            // Match the glyph's visible center, rather than the font's line box.
            y: (parent.height - labelMetrics.tightBoundingRect.height) / 2
                - baselineOffset - labelMetrics.tightBoundingRect.y
            visible: root.label.length > 0
            text: root.label
            color: root.foreground
        }

        UI.GlyphText {
            id: icon
            // Center the visible glyph rather than the font's advance and line box.
            x: (root.label.length > 0
                ? parent.width - Theme.controlFieldPadding - iconMetrics.tightBoundingRect.width
                : (parent.width - iconMetrics.tightBoundingRect.width) / 2) - iconMetrics.tightBoundingRect.x
            y: (parent.height - iconMetrics.tightBoundingRect.height) / 2
                - baselineOffset - iconMetrics.tightBoundingRect.y
            text: root.glyph
            color: root.foreground
        }

        TextMetrics {
            id: labelMetrics
            font: codeLabel.font
            text: codeLabel.text
        }

        TextMetrics {
            id: iconMetrics
            font: icon.font
            text: icon.text
        }
    }

    QC.ToolTip {
        visible: root.hovered && root.shortcutHint.length > 0
        text: root.shortcutHint
        delay: 500
        contentItem: UI.ColumnText { text: root.shortcutHint; color: Theme.accent }
        background: Rectangle { color: Theme.tooltipBackground; border.color: Theme.accent; border.width: 1 }
    }
}
