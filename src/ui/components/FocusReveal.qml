pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    id: root
    required property Item owner
    function mouseFocused(item: var): bool { return item.focusReason === Qt.MouseFocusReason }
    function reveal() {
        if (!owner.activeFocus || mouseFocused(owner)) return
        for (let parent = owner.parent; parent; parent = parent.parent) {
            if (!(parent instanceof Flickable)) continue
            const scroll = parent as Flickable
            const top = owner.mapToItem(scroll.contentItem,0,0)
            if (owner.height <= scroll.height) scroll.contentY = Math.max(scroll.originY,
                Math.min(scroll.originY + Math.max(0,scroll.contentHeight-scroll.height),
                    Math.max(top.y + owner.height-scroll.height,Math.min(scroll.contentY,top.y))))
            if (owner.width <= scroll.width) scroll.contentX = Math.max(scroll.originX,
                Math.min(scroll.originX + Math.max(0,scroll.contentWidth-scroll.width),
                    Math.max(top.x + owner.width-scroll.width,Math.min(scroll.contentX,top.x))))
        }
    }
    property Connections connections: Connections {
        target: root.owner
        function onActiveFocusChanged() { if (root.owner.activeFocus) Qt.callLater(root.reveal) }
    }
}
