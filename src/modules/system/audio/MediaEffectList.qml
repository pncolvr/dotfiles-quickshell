pragma ComponentBehavior: Bound
import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI

Rectangle {
    id: root
    property var options: []
    property string selectedName: ""
    property alias view: choices
    property real rowHeight: Theme.audioAppOptionRowHeight
    signal selected(string name)
    color: Theme.selectionBackground
    radius: Theme.audioDeviceRadius
    border.width: 1
    border.color: Theme.selectionBorder
    UI.SelectionList {
        id: choices
        objectName: "mediaEffectChoices"
        anchors.fill: parent
        anchors.margins: Theme.selectionPopupPadding
        options: root.options
        selectedName: root.selectedName
        rowHeight: root.rowHeight
        descriptionAlignment: Text.AlignHCenter
        onSelected: name => root.selected(name)
    }
}
