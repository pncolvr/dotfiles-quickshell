import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../../theme/"
import "../../../theme/ui" as UI

UI.WrapperMouseArea {
    id: root
    required property SystemTrayItem item
    required property var window

    implicitWidth: Theme.trayItemWidth
    implicitHeight: Theme.trayItemHeight
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    Image {
        anchors.centerIn: parent
        width: Theme.trayItemWidth
        height: Theme.trayItemHeight
        sourceSize.width: Theme.trayItemWidth
        sourceSize.height: Theme.trayItemHeight
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        source: root.item?.icon ?? Quickshell.iconPath("application-x-executable", false)
    }

    QsMenuAnchor {
        id: menu
        anchor.window: root.window
        anchor.rect: {
            var pos = root.window.contentItem.mapFromItem(root, 0, 0)
            return Qt.rect(pos.x, root.window.height, root.width, 0)
        }
        menu: root.item?.menu ?? null
    }
    onClicked: (mouse) => {
        switch (mouse.button) {
        case Qt.LeftButton:
            root.item.activate()
            break
        case Qt.RightButton:
            menu.open()
            break
        }
    }
}