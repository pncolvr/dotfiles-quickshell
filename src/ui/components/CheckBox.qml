pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import ".." as UI

QC.CheckBox {
    id: root
    UI.FocusReveal { owner: root }
    UI.PointerFocus {}
    padding: Theme.controlFieldPadding
    spacing: Theme.controlSpacing
    implicitHeight: Theme.controlHeight
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: Theme.fontBold
    indicator: Rectangle {
        x: root.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Theme.fontSize + 4
        implicitHeight: implicitWidth
        radius: Theme.iconButtonRadius
        color: Theme.alternateBackground
        border.width: 1
        border.color: root.visualFocus ? Theme.accent : Theme.empty
        UI.IconText { anchors.centerIn: parent; text: root.checked ? Theme.checkIcon : ""; color: Theme.accent }
    }
    contentItem: UI.ColumnText {
        leftPadding: root.indicator.width + root.spacing
        text: root.text
        verticalAlignment: Text.AlignVCenter
    }
}
