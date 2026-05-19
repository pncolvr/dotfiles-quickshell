import QtQuick
import QtQuick.Controls as QC
import "../../"

Item {
    id: root
    anchors.fill: parent

    signal clicked

    property string text: ""
    property int delay: 500
    property int cursorShape: Qt.ArrowCursor

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.cursorShape
        onClicked: root.clicked()
    }

    QC.ToolTip {
        visible: mouseArea.containsMouse && root.text.length > 0
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
