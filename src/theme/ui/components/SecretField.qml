pragma ComponentBehavior: Bound

import "../../../i18n"
import QtQuick
import "../../"
import "../" as UI

UI.InputField {
    id: root
    property bool revealed: false
    property string revealObjectName: "revealSecret"
    property string revealHint: Translations.text("secrets.actions.revealValue")
    property string hideHint: Translations.text("secrets.actions.hideValue")

    retainPanelWhileEditing: false
    echoMode: revealed ? TextInput.Normal : TextInput.Password
    passwordMaskDelay: 0
    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhHiddenText | Qt.ImhNoPredictiveText
    rightPadding: reveal.width + Theme.controlFieldPadding * 2
    onVisibleChanged: if (!visible) revealed = false
    Keys.onShortcutOverride: event => {
        if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true
    }
    Keys.onPressed: event => {
        if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true
    }
    UI.ActionButton {
        id: reveal
        objectName: root.revealObjectName
        anchors.right: parent.right
        anchors.rightMargin: Theme.controlFieldPadding
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Theme.controlHeight
        implicitHeight: parent.height - 4
        glyph: root.revealed ? Theme.eyeSlashIcon : Theme.eyeIcon
        hint: root.revealed ? root.hideHint : root.revealHint
        checkable: true
        checked: root.revealed
        onClicked: {
            root.revealed = !root.revealed
            root.forceActiveFocus()
        }
    }
}
