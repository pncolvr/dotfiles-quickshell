import QtQuick
import QtQuick as Q
import QtQuick.Controls as QC
import "../../"

Item {
    id: root
    anchors.fill: parent
    // Text labels may fill a row; anchor the hint to the displayed text.
    readonly property Q.Text label: parent as Q.Text
    readonly property real labelWidth: label ? Math.min(label.contentWidth, label.width) : 0
    readonly property real labelOffset: !label ? 0
        : label.effectiveHorizontalAlignment === Q.Text.AlignHCenter ? (label.width - labelWidth) / 2
        : label.effectiveHorizontalAlignment === Q.Text.AlignRight ? label.width - labelWidth : 0
    anchors.leftMargin: labelOffset
    anchors.rightMargin: label ? label.width - labelWidth - labelOffset : 0

    signal clicked

    property string text: ""
    property int delay: 500
    property int cursorShape: Qt.ArrowCursor
    // Controls already handle pointer input; use their hover state without covering clicks.
    property var hoverTarget: null

    MouseArea {
        id: mouseArea
        enabled: root.enabled && !root.hoverTarget
        anchors.fill: parent
        hoverEnabled: true
        // A disabled MouseArea can still override the control's cursor.
        cursorShape: root.hoverTarget ? undefined : root.cursorShape
        onClicked: root.clicked()
    }

    QC.ToolTip {
        enabled: root.enabled
        visible: root.enabled && (root.hoverTarget ? root.hoverTarget.hovered : mouseArea.containsMouse) && root.text.length > 0
        text: root.text
        delay: root.delay
        leftPadding: 6
        rightPadding: 6
        topPadding: 4
        bottomPadding: 4

        contentItem: Text {
            text: root.text
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: Theme.fontBold
            font.styleName: Theme.fontStyle
            font.weight: Theme.fontWeight
        }

        background: Rectangle {
            color: Theme.tooltipBackground
            border.color: Theme.accent
            border.width: 1
        }
    }
}
