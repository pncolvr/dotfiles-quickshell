pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../theme/ui" as UI

Item {
    id: root
    required property var picker
    property bool backgroundVisible: false
    property bool secretRevealed: false
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
        UI.InputField {
            id: secret
            objectName: "secretInput"
            width: parent.width
            pauseTooltipDismissal: false
            echoMode: root.secretRevealed ? TextInput.Normal : TextInput.Password
            rightPadding: reveal.width + Theme.controlFieldPadding * 2
            passwordMaskDelay: 0
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhHiddenText | Qt.ImhNoPredictiveText
            Accessible.name: root.picker.prompt
            Keys.onShortcutOverride: event => {
                if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true
            }
            Keys.onPressed: event => {
                if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true
            }
            UI.ActionButton {
                id: reveal
                objectName: "revealSecret"
                anchors.right: parent.right
                anchors.rightMargin: Theme.controlFieldPadding
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: Theme.controlHeight
                implicitHeight: parent.height - 4
                glyph: root.secretRevealed ? Theme.eyeSlashIcon : Theme.eyeIcon
                hint: root.secretRevealed ? "Hide password" : "Show password"
                checkable: true
                checked: root.secretRevealed
                onClicked: {
                    root.secretRevealed = !root.secretRevealed
                    secret.forceActiveFocus()
                }
            }
            Keys.onReturnPressed: root.accept()
            Keys.onEnterPressed: root.accept()
            Keys.onEscapePressed: { root.clearSecret(); root.picker.close() }
        }
    }
}
