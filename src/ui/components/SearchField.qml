pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import ".." as UI
import "../../theme"
import "../../services"

UI.InputField {
    id: root
    retainPanelWhileEditing: false
    readonly property string query: text.trim().toLowerCase()
    property bool resetWithTooltip: true
    property bool handleEscape: !TooltipService.keyboardActive
    rightPadding: Theme.controlFieldPadding + (clearButton.visible ? clearButton.width : 0)
    Accessible.name: placeholderText
    UI.PanelShortcut { owner: root; action: "search"; actionEnabled: !root.readOnly; onActivated: root.forceActiveFocus(Qt.ShortcutFocusReason) }

    function resetSearch() { clear(); focus = false }

    Connections {
        target: TooltipService
        function onVisibleChanged() { if (root.resetWithTooltip && !TooltipService.visible) root.resetSearch() }
    }

    Keys.onPressed: event => {
        if (root.handleEscape) UI.Keybinds.handleCancel(event, () => root.resetSearch())
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
        enabled: !root.readOnly
        glyph: Theme.cancelIcon
        foreground: hovered ? Theme.text : Theme.inactive
        hint: Translations.text("common.actions.clearSearch")
        onClicked: { root.clear(); root.forceActiveFocus() }
    }
}
