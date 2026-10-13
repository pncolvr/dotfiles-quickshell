pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../../theme"
import "../../../theme/ui" as UI

Rectangle {
    id: root
    property var options: []
    property string selectedName: ""
    property alias view: choices
    property real rowHeight: Theme.audioAppOptionRowHeight
    signal selected(string name)
    color: Qt.alpha(Theme.alternateBackground, 1)
    radius: Theme.audioDeviceRadius
    function revealSelected() {
        const index = options.findIndex(option => option.name === selectedName);
        choices.currentIndex = index;
        if (index >= 0) choices.positionViewAtIndex(index, ListView.Contain);
    }
    onSelectedNameChanged: Qt.callLater(revealSelected)
    onOptionsChanged: Qt.callLater(revealSelected)
    Component.onCompleted: Qt.callLater(revealSelected)
    ListView {
        id: choices
        objectName: "mediaEffectChoices"
        anchors.fill: parent
        anchors.margins: 4
        model: root.options
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        Keys.onReturnPressed: if (currentIndex >= 0) root.selected(root.options[currentIndex].name)
        delegate: QC.ItemDelegate {
            id: option
            required property var modelData
            width: choices.width
            height: root.rowHeight
            hoverEnabled: true
            enabled: modelData.available !== false
            highlighted: modelData.name === root.selectedName
            Accessible.name: modelData.description
            UI.PointerFocus {}
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            onClicked: root.selected(modelData.name)
            background: Rectangle {
                radius: Theme.iconButtonRadius
                color: hover.hovered || option.hovered || option.visualFocus
                    ? Qt.alpha(Qt.lighter(Theme.alternateBackground, 1.5), 1)
                    : root.color
            }
            contentItem: UI.ColumnText {
                text: option.modelData.description
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: option.highlighted ? Theme.accent : Theme.text
            }
        }
        QC.ScrollBar.vertical: UI.ScrollBar {}
    }
}
