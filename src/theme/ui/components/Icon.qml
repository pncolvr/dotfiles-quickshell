import QtQuick
import "../"

Rectangle {
    id: root
    property alias text: icon.text
    property alias iconColor: icon.color
    property alias centerVertical: icon.centerVertical

    IconText {
        id: icon
        anchors.centerIn: parent
    }
}