import QtQuick
import QtQuick.Controls as QC
import "../../../theme"

QC.TextField {
    id: root
    implicitHeight: Theme.totpRowHeight
    leftPadding: Theme.totpFieldPadding
    rightPadding: Theme.totpFieldPadding
    color: Theme.text
    placeholderTextColor: Theme.inactive
    selectionColor: Theme.accent
    selectedTextColor: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: Theme.fontBold
    selectByMouse: true
    background: Rectangle {
        color: Theme.alternateBackground
        radius: Theme.iconButtonRadius
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : Theme.empty
    }
}
