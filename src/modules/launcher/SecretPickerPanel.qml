pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../theme/ui" as UI

Item {
    id: root
    required property var picker
    property bool backgroundVisible: false
    property alias secretRevealed: secret.revealed
    readonly property bool nativeDialogOpen: false
    implicitWidth: Theme.pickerWidth
    implicitHeight: content.implicitHeight + Theme.tooltipPaddingWidth * 2

    function focusSearch() { secret.forceActiveFocus() }
    function clearSecret() {
        secretRevealed = false
        secret.clear()
        secret.focus = false
    }
    function accept() {
        if (!secret.text.length) return
        root.picker.acceptSecret(secret.text)
        clearSecret()
    }
    Component.onDestruction: clearSecret()
    Connections {
        target: root.picker
        function onVisibleChanged() { if (!root.picker.visible) root.clearSecret() }
    }
    Column {
        id: content
        x: Theme.tooltipPaddingWidth
        y: Theme.tooltipPaddingWidth
        width: parent.width - Theme.tooltipPaddingWidth * 2
        spacing: Theme.controlSpacing
        UI.Text {
            centerVertical: false
            width: parent.width
            text: root.picker.prompt
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        UI.Text {
            centerVertical: false
            width: parent.width
            visible: text.length > 0
            text: root.picker.secretDescription
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        UI.Text {
            centerVertical: false
            width: parent.width
            visible: text.length > 0
            text: root.picker.error
            color: Theme.warning
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        UI.SecretField {
            id: secret
            objectName: "secretInput"
            width: parent.width
            revealHint: "Show password"
            hideHint: "Hide password"
            Accessible.name: root.picker.prompt
            Keys.onReturnPressed: root.accept()
            Keys.onEnterPressed: root.accept()
            Keys.onEscapePressed: { root.clearSecret(); root.picker.close() }
        }
    }
}
