pragma ComponentBehavior: Bound

import QtQuick
import "../" as UI
import "../../"
import "../../../services"

UI.InputField {
    id: root
    readonly property string query: text.trim().toLowerCase()
    property bool resetWithTooltip: true
    property bool handleEscape: true
    rightPadding: Theme.controlFieldPadding + (clearButton.visible ? clearButton.width : 0)
    Accessible.name: placeholderText

    function resetSearch() { clear(); focus = false }

    Connections {
        target: TooltipService
        function onVisibleChanged() { if (root.resetWithTooltip && !TooltipService.visible) root.resetSearch() }
    }

    Keys.onEscapePressed: event => {
        if (!handleEscape) { event.accepted = false; return }
        resetSearch()
        if (pauseTooltipDismissal) TooltipService.resumeDismissal()
    }

    UI.ActionButton {
        id: clearButton
        objectName: "clearSearch"
        anchors.right: parent.right
        anchors.rightMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.actionButtonWidth
        height: parent.height - 2
        visible: root.text.length > 0
        focusPolicy: Qt.NoFocus
        glyph: Theme.cancelIcon
        foreground: hovered ? Theme.text : Theme.inactive
        fillColor: "transparent"
        hint: "Clear search"
        onClicked: { root.clear(); root.forceActiveFocus() }
    }
}
