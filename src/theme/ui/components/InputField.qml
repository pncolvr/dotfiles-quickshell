import QtQuick
import QtQuick.Controls as QC
import "../../"
import "../../../services"

QC.TextField {
    id: root
    property bool pauseTooltipDismissal: true
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.controlFieldPadding
    rightPadding: Theme.controlFieldPadding
    color: Theme.text
    placeholderTextColor: Theme.inactive
    selectionColor: Theme.accent
    selectedTextColor: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: Theme.fontBold
    selectByMouse: true
    onActiveFocusChanged: if (activeFocus && pauseTooltipDismissal) TooltipService.pauseDismissal()
    onTextEdited: if (pauseTooltipDismissal) TooltipService.pauseDismissal()
    background: Rectangle {
        color: Theme.alternateBackground
        radius: Theme.iconButtonRadius
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : Theme.empty
    }
}
