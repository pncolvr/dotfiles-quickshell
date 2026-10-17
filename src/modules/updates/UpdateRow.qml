import "../../i18n"
import QtQuick
import "../../ui" as UI
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

            UpdateVersionText {
                id: oldVersion
                width: Math.min(implicitWidth, Math.max(versions.availableVersionWidth / 2,
                    versions.availableVersionWidth - newVersion.implicitWidth))
                version: root.update.oldVersion
                sharedPrefix: root._shared
                changeColor: Theme.urgent
                hint: Translations.text("updates.version.installed",[root.update.oldVersion])
                onClicked: UpdatesService.openPackage(root.update)
            }

            UI.IconText {
                id: arrow
                text: Theme.rightIcon
                color: Theme.updatesUnchangedColor
            }

            UpdateVersionText {
                id: newVersion
                width: Math.min(implicitWidth, Math.max(versions.availableVersionWidth / 2,
                    versions.availableVersionWidth - oldVersion.implicitWidth))
                version: root.update.newVersion
                sharedPrefix: root._shared
                changeColor: Theme.active
                hint: Translations.text("updates.version.available",[root.update.newVersion])
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

    property string _shared: sharedPrefix(update.oldVersion, update.newVersion)

}
