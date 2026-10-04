pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../../config"
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Column {
    id: root
    readonly property var tooltipWindow: root.QsWindow.window
    readonly property var monitor: TooltipService.screen ?? tooltipWindow?.screen
    readonly property real monitorHeight: monitor?.height ?? 1080
    readonly property real monitorWidth: monitor?.width ?? Theme.totpTooltipWidth
    width: Math.min(Theme.totpTooltipWidth, monitorWidth - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.totpSpacing
    property string editingId: ""
    property bool adding: false
    property string draftName: ""
    property string draftToken: ""
    readonly property real nameWidth: (width - Theme.totpButtonWidth * 2 - Theme.totpSpacing * 3) * 0.42

    function cancelEditor() { editingId = ""; adding = false; draftName = ""; draftToken = "" }

    UI.ColumnText {
        width: parent.width
        visible: TotpService.error.length > 0
        textFormat: Text.PlainText
        text: TotpService.error
        wrapMode: Text.Wrap
        color: Theme.warning
    }

    UI.ColumnText {
        width: parent.width
        visible: !TotpService.ready && TotpService.error.length === 0
        text: "opening keyring…"
        color: Theme.inactive
    }

    UI.ColumnText {
        width: parent.width
        visible: TotpService.ready && TotpService.entries.count === 0
        text: "no tokens yet — add a secret below"
        color: Theme.inactive
    }

    ListView {
        id: list
        objectName: "totpList"
        width: parent.width
        readonly property real minimumHeight: Config.totpListMinRows * Theme.totpRowHeight
            + Math.max(0, Config.totpListMinRows - 1) * spacing
        height: Math.max(minimumHeight, Math.min(contentHeight, root.monitorHeight * Config.totpListMaxScreenHeight))
        spacing: Theme.totpSpacing
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: TotpService.entries
        delegate: TotpRow {
            width: list.width - (scrollbar.visible ? Theme.totpScrollbarWidth + Theme.totpScrollbarMargin : 0)
            editing: root.editingId === entryId
            nameWidth: root.nameWidth
            draftName: root.draftName
            draftToken: root.draftToken
            onEditRequested: entryId => {
                root.cancelEditor()
                root.editingId = entryId
                if (!TotpService.edit(entryId)) root.editingId = ""
            }
            onEditCancelled: root.cancelEditor()
            onDraftChanged: (name, token) => { root.draftName = name; root.draftToken = token }
        }
        QC.ScrollBar.vertical: QC.ScrollBar {
            id: scrollbar
            implicitWidth: Theme.totpScrollbarWidth
            visible: list.contentHeight > list.height
            policy: QC.ScrollBar.AsNeeded
            contentItem: Rectangle { radius: width / 2; color: Theme.accent; opacity: scrollbar.active ? 1 : 0.5 }
            background: Rectangle { color: Theme.empty; radius: width / 2 }
        }
    }

    Item {
        id: countdown
        width: parent.width
        visible: TotpService.ready && TotpService.entries.count > 0
        height: Theme.totpCountdownHeight + Theme.totpCountdownListMargin
        readonly property color progressColor: TotpService.secondsRemaining <= Theme.totpExpiryWarning ? Theme.warning : Theme.accent

        UI.Text {
            id: seconds
            anchors.left: parent.left
            y: Theme.totpCountdownListMargin
            width: Math.max(Theme.totpCountdownTextWidth, implicitWidth)
            height: Theme.totpCountdownHeight
            centerVertical: false
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            text: String(TotpService.secondsRemaining)
            color: countdown.progressColor
        }

        Rectangle {
            anchors.left: seconds.right
            anchors.right: parent.right
            anchors.leftMargin: Theme.totpSpacing
            y: Theme.totpCountdownListMargin + (Theme.totpCountdownHeight - height) / 2
            height: Theme.totpCountdownStrokeWidth
            radius: height / 2
            antialiasing: true
            color: Theme.empty
            Rectangle {
                anchors.left: parent.left
                width: parent.width * TotpService.countdownProgress
                height: parent.height
                radius: height / 2
                antialiasing: true
                color: countdown.progressColor
            }
        }
    }

    // Reserve one row in either mode, so the add form does not resize the popup.
    Item {
        width: parent.width
        height: Theme.totpRowHeight + Theme.totpFooterMargin

        UI.ActionButton {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: !root.adding
            glyph: TotpService.error.length > 0 ? Theme.retryIcon : Theme.addIcon
            hint: TotpService.error.length > 0 ? "reload keyring" : "add token"
            enabled: !TotpService.busy
            onClicked: {
                if (TotpService.error.length > 0) { root.cancelEditor(); TotpService.reload() }
                else {
                    root.cancelEditor()
                    root.adding = true
                }
            }
        }

        Loader {
            id: addLoader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            active: root.adding
            onLoaded: (item as TotpEditor).begin("", "")
            sourceComponent: TotpEditor {
                adding: true
                nameWidth: root.nameWidth
                busy: TotpService.busy
                onSubmitted: (name, token) => TotpService.save("", name, token)
                onCancelled: root.adding = false
            }
        }
    }

    Connections {
        target: TotpService
        function onSaved(entryId) { root.cancelEditor() }
        function onEditFailed() { root.cancelEditor() }
        function onEditorLoaded(entryId, name, token) {
            if (root.editingId === entryId) { root.draftName = name; root.draftToken = token }
        }
    }
}
