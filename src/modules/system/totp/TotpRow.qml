pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Item {
    id: root
    required property string entryId
    required property string name
    required property string code
    required property real expiresAt
    required property bool editing
    required property real nameWidth
    required property string draftName
    required property string draftToken
    readonly property TotpEditor editor: editorLoader.item as TotpEditor
    signal editRequested(string entryId)
    signal editCancelled()
    signal draftChanged(string name, string token)
    implicitHeight: Theme.totpRowHeight

    Rectangle {
        anchors.fill: parent
        visible: rowHover.hovered
        color: Theme.totpRowHoverBackground
        radius: Theme.iconButtonRadius
    }

    HoverHandler { id: rowHover }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.totpSpacing
        visible: !root.editing

        UI.Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            centerVertical: false
            textFormat: Text.PlainText
            text: root.name
            elide: Text.ElideRight
            UI.HoverTooltip { text: root.name }
        }

        UI.ActionButton {
            Layout.preferredWidth: Theme.totpCodeWidth
            glyph: TotpService.copiedId === root.entryId ? Theme.checkIcon : Theme.copyIcon
            label: root.code.replace(/(.{3})(?=.)/g, "$1 ")
            hint: TotpService.copiedId === root.entryId ? "copied" : "copy code"
            foreground: TotpService.copiedId === root.entryId ? Theme.active : Theme.text
            enabled: !TotpService.busy
            onClicked: TotpService.copy(root.entryId)
        }

        UI.ActionButton {
            glyph: Theme.editIcon
            hint: "edit token"
            enabled: !TotpService.busy
            onClicked: root.editRequested(root.entryId)
        }

        UI.ActionButton {
            glyph: Theme.deleteIcon
            hint: "delete token"
            fillColor: Theme.totpDeleteBackground
            enabled: !TotpService.busy
            onClicked: TotpService.remove(root.entryId)
        }
    }

    Loader {
        id: editorLoader
        anchors.fill: parent
        active: root.editing
        onLoaded: root.editor.begin(root.draftName, root.draftToken)
        sourceComponent: TotpEditor {
            nameWidth: root.nameWidth
            busy: TotpService.busy
            onSubmitted: (name, token) => TotpService.save(root.entryId, name, token)
            onCancelled: root.editCancelled()
            onDraftChanged: (name, token) => root.draftChanged(name, token)
        }
    }

    Connections {
        target: TotpService
        function onEditorLoaded(entryId, name, token) {
            if (root.editing && root.entryId === entryId && root.editor)
                root.editor.begin(name, token)
        }
    }
}
