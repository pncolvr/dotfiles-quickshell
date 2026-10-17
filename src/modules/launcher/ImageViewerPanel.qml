pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui" as UI
import "../../services"

Rectangle {
    id: root
    property var picker: PickerService
    property bool backgroundVisible: true
    property real availableContentHeight: 800
    implicitWidth: Math.min(Theme.pickerWidth, Theme.qrPreviewSize)
    implicitHeight: Math.min(Theme.qrPreviewSize, availableContentHeight)
    radius: Theme.tooltipRadius
    color: backgroundVisible ? Qt.rgba(Theme.tooltipBackground.r, Theme.tooltipBackground.g,
        Theme.tooltipBackground.b, Theme.tooltipBackground.a * Theme.pickerBackgroundOpacity) : "transparent"

    function focusSearch() { root.forceActiveFocus() }
    Keys.onEscapePressed: picker.close()
    Keys.onReturnPressed: picker.accept(false, false)
    Keys.onEnterPressed: picker.accept(false, false)

    Connections {
        target: root.picker
        function onOpened() { Qt.callLater(root.focusSearch) }
    }
    Rectangle {
        id: viewport
        anchors.fill: parent
        anchors.margins: Theme.tooltipPaddingHeight
        color: "white"
        Image {
            id: image
            objectName: "imageViewer"
            anchors.centerIn: parent
            // Enlarge QR modules by whole pixels when there is room.
            readonly property real fitScale: Math.min(viewport.width / Math.max(1, implicitWidth),
                viewport.height / Math.max(1, implicitHeight))
            readonly property real imageScale: fitScale >= 1 ? Math.floor(fitScale) : Math.max(0, fitScale)
            width: implicitWidth * imageScale
            height: implicitHeight * imageScale
            source: root.picker.visible ? root.picker.currentItem?.image ?? "" : ""
            fillMode: Image.PreserveAspectFit
            smooth: false
            mipmap: false
            cache: false
            asynchronous: true
            onStatusChanged: if (status === Image.Error && root.picker.visible) root.picker.imagePreviewFailed()
            Accessible.role: Accessible.Graphic
            Accessible.name: root.picker.currentItem?.title ?? Translations.text("images.viewer.title")
        }
        UI.Text {
            centerVertical: false
            anchors.centerIn: parent
            visible: image.status === Image.Error
            text: Translations.text("images.preview.unavailable")
            color: "black"
        }
    }
}
