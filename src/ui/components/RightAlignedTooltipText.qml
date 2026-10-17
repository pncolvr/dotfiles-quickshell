import QtQuick
import ".."

RightAlignedText {
    id: root
    property string hint: ""
    property int cursorShape: Qt.ArrowCursor

    signal clicked

    HoverTooltip {
        text: root.hint
        cursorShape: root.cursorShape
        onClicked: root.clicked()
    }
}
