import QtQuick
import QtQuick as Q
import QtQuick.Controls as QC
import "../../"
import "../" as UI

QC.Button {
    id: root
    property string glyph: ""
    property string label: ""
    property string hint: ""
    property color fillColor: Theme.alternateBackground
    property color foreground: Theme.text

    implicitWidth: Theme.actionButtonWidth
    implicitHeight: Theme.controlHeight
    padding: 0
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    Accessible.name: hint || label

    background: Rectangle {
        color: root.down ? Qt.darker(root.fillColor, 1.2) : root.hovered ? Qt.lighter(root.fillColor, 1.4) : root.fillColor
        radius: Theme.iconButtonRadius
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.accent
    }

    contentItem: Item {
        implicitWidth: codeLabel.visible
            ? codeLabel.implicitWidth + (icon.implicitWidth + Theme.controlSpacing + Theme.controlFieldPadding) * 2
            : icon.implicitWidth + Theme.controlFieldPadding * 2
        implicitHeight: Math.max(icon.implicitHeight, codeLabel.visible ? codeLabel.implicitHeight : 0)

        Q.Text {
            id: codeLabel
            anchors.centerIn: parent
            visible: root.label.length > 0
            text: root.label
            color: root.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: Theme.fontBold
        }

        Q.Text {
            id: icon
            // Center the visible glyph rather than the font's advance and line box.
            x: (codeLabel.visible
                ? parent.width - Theme.controlFieldPadding - iconMetrics.tightBoundingRect.width
                : (parent.width - iconMetrics.tightBoundingRect.width) / 2) - iconMetrics.tightBoundingRect.x
            y: (parent.height - iconMetrics.tightBoundingRect.height) / 2
                - baselineOffset - iconMetrics.tightBoundingRect.y
            text: root.glyph
            color: root.foreground
            font.family: Theme.fontFamilyIcons
            font.pixelSize: Theme.fontSize
        }

        TextMetrics {
            id: iconMetrics
            font: icon.font
            text: icon.text
        }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    QC.ToolTip {
        visible: root.hovered && root.hint.length > 0
        text: root.hint
        delay: 500
        contentItem: UI.ColumnText { text: root.hint; color: Theme.accent }
        background: Rectangle { color: Theme.tooltipBackground; border.color: Theme.accent; border.width: 1 }
    }
}
