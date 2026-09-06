import QtQuick
import "../../theme/ui" as UI
import "../../theme"
import "../../services"

Item {
    id: root
    width: parent.width
    height: content.implicitHeight

    required property var update
    required property color nameColor

    UI.WrapperMouseArea {
        anchors.fill: parent
        onClicked: UpdatesService.openPackage(root.update)
    }

    Row {
        id: content
        width: parent.width
        spacing: 0

        UI.ColumnText {
            id: name
            text: root.update.name
            color: root.nameColor
            elide: Text.ElideMiddle
            width: root.width - versions.width - content.spacing

            UI.HoverTooltip {
                text: parent.text
                cursorShape: Qt.PointingHandCursor
                onClicked: UpdatesService.openPackage(root.update)
            }
        }

        UI.ColumnText {
            id: versions
            textFormat: Text.StyledText
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, root.width - Math.min(name.implicitWidth, root.width * 0.4))
            text: `<font color="${Theme.inactive}">${root.escapeHtml(root._shared)}</font>`
                + `<font color="${Theme.urgent}">${root.escapeHtml(root.diffSuffix(root.update.oldVersion, root._shared))}</font>`
                + `<font color="${Theme.active}">${root.escapeHtml(root.diffSuffix(root.update.newVersion, root._shared))}</font>`

            UI.HoverTooltip {
                text: `${root.update.oldVersion} ➡ ${root.update.newVersion}`
                cursorShape: Qt.PointingHandCursor
                onClicked: UpdatesService.openPackage(root.update)
            }
        }
    }

    function versionParts(v) {
        return v.split(/([.\-_])/).filter(p => p.length > 0)
    }

    function sharedPrefix(a, b) {
        const pa = versionParts(a)
        const pb = versionParts(b)
        let i = 0
        while (i < pa.length && i < pb.length && pa[i] === pb[i]) i++
        return pa.slice(0, i).join("")
    }

    function diffSuffix(v, shared) {
        return v.slice(shared.length)
    }

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    property string _shared: sharedPrefix(update.oldVersion, update.newVersion)

}
