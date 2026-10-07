pragma ComponentBehavior: Bound

import QtQuick as Q
import "../../"
import "../" as UI

Q.Row {
    id: root
    property real buttonWidth: Theme.actionButtonWidth
    property real buttonHeight: Theme.controlHeight
    property bool submitEnabled: true
    property bool cancelEnabled: true
    property string submitGlyph: Theme.checkIcon
    property string submitHint: "Apply"
    property string cancelHint: "Cancel"
    property alias submitObjectName: submitButton.objectName
    property alias cancelObjectName: cancelButton.objectName
    signal submitted()
    signal cancelled()
    spacing: Theme.controlSpacing

    UI.ActionButton {
        id: cancelButton
        width: root.buttonWidth
        height: root.buttonHeight
        glyph: Theme.cancelIcon
        hint: root.cancelHint
        enabled: root.cancelEnabled
        onClicked: root.cancelled()
    }
    UI.ActionButton {
        id: submitButton
        width: root.buttonWidth
        height: root.buttonHeight
        glyph: root.submitGlyph
        hint: root.submitHint
        enabled: root.submitEnabled
        fillColor: Theme.accent
        onClicked: root.submitted()
    }
}
