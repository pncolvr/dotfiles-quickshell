import QtQuick
import QtQuick.Controls as QC
import "../../"

QC.TextArea {
    id: root
    property bool retainPanelWhileEditing: true
    property bool focusBorder: false
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: Theme.fontBold
    padding: Theme.controlFieldPadding
    textFormat: TextEdit.PlainText
    placeholderTextColor: Theme.inactive
    color: Theme.text
    wrapMode: TextEdit.Wrap
    background: Rectangle {
        color: Theme.alternateBackground
        radius: Theme.iconButtonRadius
        border.width: root.focusBorder ? 1 : 0
        border.color: root.activeFocus ? Theme.accent : Theme.empty
    }
}
