pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import ".." as UI
import "../../theme"

// Owners supply contentItem and decide how expanded content is rendered.
QC.ItemDelegate {
    id: root
    property bool expanded: false
    property bool forceExpanded: false
    property bool showChevron: true
    property color fillColor: "transparent"
    property color chevronColor: Theme.inactive
    readonly property bool showingContent: expanded || forceExpanded
    readonly property bool keyboardFocusVisible: (background as UI.ButtonSurface)?.keyboardFocusVisible ?? false
    signal expansionRequested(bool expanded)

    function requestToggle() {
        if (enabled && !forceExpanded) expansionRequested(!expanded)
    }
    implicitHeight: Theme.controlHeight
    focusPolicy: Qt.StrongFocus
    padding: Theme.controlFieldPadding
    leftPadding: padding + (showChevron ? arrow.width + Theme.controlSpacing : 0)
    rightPadding: padding
    checkable: false
    checked: showingContent
    hoverEnabled: true
    Accessible.name: text
    Accessible.expanded: showingContent
    onClicked: requestToggle()
    Keys.onReturnPressed: click()
    Keys.onEnterPressed: click()

    background: UI.ButtonSurface {
        id: surface
        control: root
        fillColor: root.fillColor
    }
    contentItem: Item {}
    UI.IconText {
        id: arrow
        objectName: "collapsibleChevron"
        x: root.padding
        width: Theme.fontSize
        visible: root.showChevron
        horizontalAlignment: Text.AlignHCenter
        text: Theme.chevronRightIcon
        rotation: root.showingContent ? 90 : 0
        UI.MotionBehavior on rotation {
            NumberAnimation { duration: Theme.selectionAnimationDuration; easing.type: Easing.OutCubic }
        }
        color: root.chevronColor
    }
}
