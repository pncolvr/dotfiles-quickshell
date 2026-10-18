pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui" as UI

Item {
    id: root
    required property var picker
    property bool backgroundVisible: false
    property alias secretRevealed: secret.revealed
    readonly property bool nativeDialogOpen: false
    readonly property bool moduleFocusSearch: true
    readonly property var modulePointerTarget: secret
    readonly property var actions: picker.secretActions ?? null
    Keys.onPressed: event => UI.Keybinds.handleCancel(event, () => { root.clearSecret(); root.picker.close() })
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: !!root.actions && root.picker.visible
        onActivated: root.accept()
    }
    implicitWidth: Theme.pickerWidth
    implicitHeight: content.implicitHeight + Theme.tooltipPaddingWidth * 2

    function focusSearch() { secret.forceActiveFocus() }
    function clearSecret() {
        secretRevealed = false
        secret.clear()
        secret.focus = false
    }
    function accept() {
        if (!secret.text.length || actions?.generating) return
        if (actions && /[\x00-\x1f\x7f]/.test(secret.text)) {
            root.picker.error = Translations.text("secrets.errors.controlCharacters")
            return
        }
        const value = secret.text
        clearSecret()
        root.picker.acceptSecret(value)
    }
    // The component's JS methods may already be invalid during destruction.
    Component.onDestruction: { secret.revealed = false; secret.clear(); secret.focus = false }
    Connections {
        target: root.picker
        function onVisibleChanged() { if (!root.picker.visible) root.clearSecret() }
    }
    Connections {
        target: root.actions
        function onGenerated(value) { secret.text = value; root.focusSearch() }
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
            maximumLength: root.actions ? 1024 : 32767
            revealHint: Translations.text("secrets.actions.revealPassword")
            hideHint: Translations.text("secrets.actions.hidePassword")
            Accessible.name: root.picker.prompt
            Keys.onReturnPressed: root.accept()
            Keys.onEnterPressed: root.accept()
            Keys.onPressed: event => UI.Keybinds.handleCancel(event, () => { root.clearSecret(); root.picker.close() })
        }
        Column {
            width: parent.width
            spacing: Theme.controlSpacing
            visible: !!root.actions
            Row {
                id: passwordActions
                anchors.right: parent.right
                spacing: Theme.controlSpacing
                UI.ActionButton {
                    objectName: "generateBackupPassword"
                    visible: root.actions?.creating ?? false
                    glyph: Theme.retryIcon
                    hint: Translations.text("secrets.actions.generatePassword")
                    enabled: !root.actions?.generating
                    onClicked: root.actions.generate()
                }
                UI.CopyButton {
                    objectName: "copyBackupPassword"
                    visible: root.actions?.creating ?? false
                    copyHint: Translations.text("secrets.actions.copyPassword")
                    enabled: secret.text.length > 0
                    copyAction: completed => { root.actions.copy(secret.text, completed); root.focusSearch() }
                }
            }
            UI.ShortcutHints {
                width: parent.width
                panelKey: "default"
                availableActions: []
            }
        }
    }
}
