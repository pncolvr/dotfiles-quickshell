pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../theme"

// Common interaction and selection surface; specialized rows own their contents.
QC.ItemDelegate {
    id: root
    property bool current: false
    property bool activateOnClick: true
    property int cursorShape: Qt.PointingHandCursor
    readonly property bool pointerHovered: hover.hovered
    property color currentBackground: Theme.alternateBackground
    property color hoverBackground: "transparent"
    property color idleBackground: "transparent"
    property color currentForeground: Theme.accent
    readonly property color foreground: current ? currentForeground : Theme.text
    readonly property color secondaryForeground: current ? currentForeground : Theme.inactive
    property alias color: surface.color
    property alias radius: surface.radius
    property int pointerModifiers: Qt.NoModifier
    signal chosen(bool toggle)
    signal activated()
    hoverEnabled: true
    padding: Theme.pickerRowPadding
    leftPadding: Theme.controlFieldPadding
    rightPadding: Theme.controlFieldPadding
    height: Math.max(Theme.controlHeight, contentItem.implicitHeight + topPadding + bottomPadding)
    background: Rectangle {
        id: surface
        color: root.current ? root.currentBackground : root.pointerHovered ? root.hoverBackground : root.idleBackground
        radius: Theme.iconButtonRadius
    }
    onClicked: {
        chosen((pointerModifiers & Qt.ControlModifier) !== 0)
        if (activateOnClick) activated()
    }
    onDoubleClicked: if (!activateOnClick) activated()
    HoverHandler { id: hover; cursorShape: root.cursorShape }
    MouseArea {
        anchors.fill: parent
        cursorShape: root.cursorShape
        onPressed: {
            if (root.focusPolicy & Qt.ClickFocus) root.forceActiveFocus(Qt.MouseFocusReason)
        }
        onClicked: mouse => {
            root.pointerModifiers = mouse.modifiers
            root.click()
            root.pointerModifiers = Qt.NoModifier
        }
        onDoubleClicked: root.doubleClicked()
    }
    Keys.onReturnPressed: click()
    Keys.onEnterPressed: click()
}
