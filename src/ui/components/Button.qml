pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../theme"

QC.Button {
    id: root
    property color fillColor: Theme.alternateBackground
    property color hoverColor: Theme.buttonHoverColor(fillColor)
    property color pressedColor: Theme.buttonPressedColor(hoverColor)
    property color foreground: Theme.foregroundOn((background as Rectangle)?.color ?? fillColor)
    readonly property bool keyboardFocusVisible: (background as ButtonSurface)?.keyboardFocusVisible ?? false
    property real cornerRadius: Theme.iconButtonRadius
    implicitHeight: Theme.controlHeight
    hoverEnabled: true
    Keys.onReturnPressed: click()
    Keys.onEnterPressed: click()
    opacity: enabled ? 1 : 0.45
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: Theme.fontBold
    background: ButtonSurface {
        id: surface
        control: root
        fillColor: root.fillColor
        hoverColor: root.hoverColor
        pressedColor: root.pressedColor
        radius: root.cornerRadius
    }
    contentItem: ColumnText {
        readonly property bool adaptiveContrastExcluded: true
        text: root.text
        color: root.foreground
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
