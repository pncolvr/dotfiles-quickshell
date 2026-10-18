pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import QtQuick.Window
import Quickshell
import "../../theme"
import ".." as UI

UI.SelectableRow {
    id: root
    required property var entry
    property bool selected: false
    property bool multiple: false
    property bool clipboard: false
    property bool showThumbnail: true
    property bool compactImage: false
    readonly property bool clipboardImage: showThumbnail && clipboard && !!entry.image && !compactImage
    property bool grid: false
    padding: 0
    focusPolicy: Qt.NoFocus
    currentBackground: Theme.accent
    hoverBackground: Theme.alternateBackground
    currentForeground: Theme.selectionText
    activateOnClick: !clipboard
    implicitHeight: grid ? Theme.pickerGridHeight : clipboardImage
        ? thumbnail.height + (textBlock.implicitHeight > 0 ? Theme.controlSpacing + textBlock.implicitHeight : 0) + Theme.pickerRowPadding * 2
        : Math.max(
        textBlock.implicitHeight + Theme.pickerRowPadding * 2,
        thumbnail.visible ? thumbnail.height + Theme.pickerRowPadding * 2 : 0)
    height: implicitHeight
    Accessible.name: entry.title || (clipboard && entry.image ? Translations.text("clipboard.image.accessibleName") : "")
    Accessible.role: multiple ? Accessible.CheckBox : Accessible.ListItem
    Accessible.checkable: multiple
    Accessible.checked: selected

    UI.Icon {
        id: selectionBox
        anchors.left: parent.left
        anchors.leftMargin: Theme.controlFieldPadding
        anchors.verticalCenter: parent.verticalCenter
        width: 16; height: 16
        visible: root.multiple
        color: "transparent"
        radius: 3
        border.width: 1
        border.color: root.current || root.selected ? root.foreground : Theme.inactive
        iconColor: root.foreground
        text: root.selected ? Theme.checkIcon : ""
    }
    UI.ScaledImage {
        id: thumbnail
        objectName: "pickerRowImage"
        anchors.left: parent.left
        anchors.leftMargin: Theme.controlFieldPadding + (root.multiple ? selectionBox.width + Theme.controlSpacing : 0)
        anchors.verticalCenter: root.clipboardImage ? undefined : parent.verticalCenter
        anchors.top: root.clipboardImage ? parent.top : undefined
        anchors.topMargin: Theme.pickerRowPadding
        width: root.clipboardImage ? root.width - anchors.leftMargin - Theme.controlFieldPadding
            - (pinMarker.visible ? pinMarker.width + Theme.controlSpacing : 0)
            : root.clipboard ? 44 : 18
        height: root.clipboardImage ? Theme.clipboardImagePreviewHeight : root.clipboard ? 36 : 18
        source: root.showThumbnail ? root.entry.image || (root.entry.icon ? Quickshell.iconPath(root.entry.icon, true) : "") : ""
        visible: source.toString().length > 0 && !root.grid
        sourceSize: Qt.size(Math.ceil(width * (root.clipboardImage ? Screen.devicePixelRatio : 1)), Math.ceil(height * (root.clipboardImage ? Screen.devicePixelRatio : 1)))
        asynchronous: true
    }
    Column {
        id: textBlock
        anchors.left: parent.left
        anchors.leftMargin: Theme.controlFieldPadding + (root.multiple ? selectionBox.width + Theme.controlSpacing : 0)
            + (thumbnail.visible && !root.clipboardImage ? thumbnail.width + Theme.controlSpacing : 0)
        anchors.right: parent.right
        anchors.rightMargin: Theme.controlFieldPadding + (pinMarker.visible ? pinMarker.width + Theme.controlSpacing : 0)
        anchors.verticalCenter: root.clipboardImage ? undefined : parent.verticalCenter
        anchors.top: root.clipboardImage ? thumbnail.bottom : undefined
        anchors.topMargin: Theme.controlSpacing
        spacing: 2
        UI.IconText {
            centerVertical: false
            width: parent.width
            visible: root.grid && text.length > 0
            text: root.entry.glyph || ""
            color: root.foreground
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
        }
        UI.Text {
            centerVertical: false
            width: parent.width
            text: root.entry.title || (root.compactImage && root.clipboard && root.entry.image
                ? Translations.text("clipboard.image.accessibleName") : "")
            color: root.foreground
            visible: text.length > 0
            textFormat: Text.PlainText
            horizontalAlignment: root.grid ? Text.AlignHCenter : Text.AlignLeft
            wrapMode: root.clipboard ? Text.Wrap : Text.NoWrap
            maximumLineCount: root.clipboard ? 3 : 1
            elide: Text.ElideRight
        }
        Row {
            width: parent.width
            visible: !root.grid && (!!root.entry.subtitle || !!root.entry.annotation)
            spacing: subtitle.visible && annotation.visible ? Theme.controlSpacing * 2 : 0
            UI.Text {
                id: subtitle
                centerVertical: false
                width: Math.max(0,parent.width - (annotation.visible ? annotation.width + parent.spacing : 0))
                text: root.entry.subtitle || ""
                visible: text.length > 0
                textFormat: Text.PlainText
                color: root.secondaryForeground
                font.pixelSize: Theme.fontSize - 1
                elide: Text.ElideRight
            }
            UI.Text {
                id: annotation
                objectName: "pickerRowAnnotation"
                readonly property string labelText: root.entry.annotation || ""
                centerVertical: false
                width: Math.min(implicitWidth,parent.width * 0.65)
                text: labelText.split(' → ').map(value=>value.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'))
                    .join(' <font face="'+Theme.fontFamilyIcons+'">'+Theme.rightIcon+'</font> ')
                visible: text.length > 0
                textFormat: Text.StyledText
                color: root.current ? Theme.selectionText : Theme.warning
                font.pixelSize: Theme.fontSize - 1
                elide: Text.ElideRight
            }
        }
    }
    UI.IconText {
        id: pinMarker
        anchors.right: parent.right
        anchors.rightMargin: Theme.controlFieldPadding
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        visible: root.entry.pinned === true
        text: Theme.filePinIcon
        color: root.current ? Theme.selectionText : Theme.accent
        horizontalAlignment: Text.AlignHCenter
    }
    UI.HoverTooltip {
        hoverTarget: root
        text: root.entry.hint || root.entry.annotation || ""
        textFormat: Text.PlainText
        maximumWidth: Math.min(640,Math.max(80,(root.Window.window?.width ?? 800)-32))
    }
}
