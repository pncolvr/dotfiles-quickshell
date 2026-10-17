pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var picker
    property bool windowPreview: false
    // Keep the last known dimensions while the next image header is loading.
    property size imageNaturalSize: Qt.size(0, 0)
    Loader {
        anchors.fill: parent
        sourceComponent: root.windowPreview ? liveWindow : image
    }
    Component {
        id: image
        ClipboardImagePreview {
            entries: root.picker.filteredItems
            entry: root.picker.filteredItems[root.picker.currentIndex] ?? null
            searching: root.picker.searchPending
            onNaturalSizeChanged: {
                if (naturalSize.width > 0 && naturalSize.height > 0) root.imageNaturalSize = naturalSize
            }
            decodeWidth: width
            decodeHeight: height
        }
    }
    Component {
        id: liveWindow
        WindowPreview { client: root.picker.currentItem?.client ?? ({address:"",class:""}) }
    }
}
