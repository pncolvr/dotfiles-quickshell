import QtQuick
import "../../theme/ui" as UI
import "../../theme"

Row {
    id: root
    width: parent.width
    spacing: 0

    required property var update
    required property color nameColor

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

    property string _shared: sharedPrefix(update.oldVersion, update.newVersion)

    UI.ColumnText {
        text: root.update.name
        color: root.nameColor
        elide: Text.ElideMiddle
        width: parent.width - versionShared.implicitWidth - versionOld.implicitWidth - versionNew.implicitWidth - root.spacing

        UI.HoverTooltip {
            text: parent.text
        }
    }

    Row {
        spacing: 0

        UI.ColumnText {
            id: versionShared
            text: root._shared
            color: Theme.inactive
        }

        UI.ColumnText {
            id: versionOld
            text: root.diffSuffix(root.update.oldVersion, root._shared)
            color: Theme.urgent
        }
    }

    UI.ColumnText {
        id: versionNew
        text: root.diffSuffix(root.update.newVersion, root._shared)
        color: Theme.active
    }
}