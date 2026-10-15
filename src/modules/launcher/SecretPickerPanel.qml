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
    readonly property bool moduleFocusSearch: true
    readonly property var modulePointerTarget: secret
    readonly property var actions: picker.secretActions ?? null
    Keys.onEscapePressed: { root.clearSecret(); root.picker.close() }
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
            root.picker.error = "Enter a password without control characters."
            return
        }
        root.picker.acceptSecret(secret.text)
        clearSecret()
    }
    Component.onDestruction: clearSecret()
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
            revealHint: "Show password"
            hideHint: "Hide password"
            Accessible.name: root.picker.prompt
            Keys.onReturnPressed: root.accept()
            Keys.onEnterPressed: root.accept()
            Keys.onEscapePressed: { root.clearSecret(); root.picker.close() }
        }
        Item {
            width: parent.width
            height: Theme.controlHeight
            visible: !!root.actions
            UI.ColumnText {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - (passwordActions.width + Theme.controlSpacing) * 2)
                horizontalAlignment: Text.AlignHCenter
                text: root.actions?.creating ? "Enter: create · Esc: cancel" : "Enter: restore · Esc: cancel"
                color: Theme.inactive
                elide: Text.ElideRight
            }
            Row {
                id: passwordActions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.controlSpacing
                UI.ActionButton {
                    objectName: "generateBackupPassword"
                    visible: root.actions?.creating ?? false
                    glyph: Theme.retryIcon
                    hint: "Generate password"
                    enabled: !root.actions?.generating
                    onClicked: root.actions.generate()
                }
                UI.ActionButton {
                    objectName: "copyBackupPassword"
                    visible: root.actions?.creating ?? false
                    glyph: Theme.copyIcon
                    hint: "Copy password"
                    enabled: secret.text.length > 0
                    onClicked: { root.actions.copy(secret.text); root.focusSearch() }
                }
            }
        }
    }
}
