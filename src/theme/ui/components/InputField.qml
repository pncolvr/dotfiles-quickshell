import QtQuick
import QtQuick.Controls as QC
import "../../"
import "../" as UI

QC.TextField {
    id: root
    UI.FocusReveal { owner: root }
    // Focus keeps inputs usable when filtering moves the panel off the pointer.
    property bool retainPanelWhileFocused: true
    property bool retainPanelWhileEditing: true
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.controlFieldPadding
    rightPadding: Theme.controlFieldPadding
    color: Theme.text
    placeholderTextColor: Theme.inactive
    selectionColor: Theme.accent
    selectedTextColor: Theme.selectionText
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: Theme.fontBold
    renderType: Theme.textRenderType
    font.hintingPreference: Theme.fontHintingPreference
    selectByMouse: true
    background: Rectangle {
        color: Theme.alternateBackground
        radius: Theme.iconButtonRadius
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : Theme.empty
    }
}
