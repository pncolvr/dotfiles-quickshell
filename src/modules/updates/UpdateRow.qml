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
        spacing: Theme.controlSpacing

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

        Row {
            id: versions
            spacing: Theme.controlSpacing
            width: Math.min(oldVersion.implicitWidth + arrow.implicitWidth + newVersion.implicitWidth + spacing * 2,
                root.width - Math.min(name.implicitWidth, root.width * 0.4) - content.spacing)
            readonly property real availableVersionWidth: Math.max(0, width - arrow.implicitWidth - spacing * 2)

            UI.ColumnText {
                id: oldVersion
                textFormat: Text.StyledText
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, Math.max(versions.availableVersionWidth / 2,
                    versions.availableVersionWidth - newVersion.implicitWidth))
                text: root.versionText(root.update.oldVersion, Theme.urgent)

                UI.HoverTooltip {
                    text: `Installed: ${root.update.oldVersion}`
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UpdatesService.openPackage(root.update)
                }
            }

            UI.IconText {
                id: arrow
                text: Theme.rightIcon
                color: Theme.updatesUnchangedColor
            }

            UI.ColumnText {
                id: newVersion
                textFormat: Text.StyledText
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, Math.max(versions.availableVersionWidth / 2,
                    versions.availableVersionWidth - oldVersion.implicitWidth))
                text: root.versionText(root.update.newVersion, Theme.active)

                UI.HoverTooltip {
                    text: `Available: ${root.update.newVersion}`
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UpdatesService.openPackage(root.update)
                }
            }
        }
    }

    function versionText(version, changeColor) {
        return '<font color="' + Theme.updatesUnchangedColor + '">' + escapeHtml(_shared) + '</font>'
            + '<font color="' + changeColor + '">' + escapeHtml(diffSuffix(version, _shared)) + '</font>'
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
