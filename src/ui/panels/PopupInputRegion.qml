pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtQml.Models
import Quickshell

// Menus can extend beyond a compact panel without exposing the whole surface.
Region {
    id: root
    required property Item overlay
    property bool enabled: true
    readonly property var popupItems: overlay
        ? Array.from(overlay.children).filter(item => item.visible && popupFor(item) !== null) : []
    function popupFor(item: var): QC.Popup {
        for (const child of item.children ?? []) {
            if (child.panelPopup) return child.panelPopup as QC.Popup
        }
        return null
    }
    function closePopups() {
        for (const item of popupItems) popupFor(item)?.close()
    }
    property Instantiator builder: Instantiator {
        model: root.enabled ? root.popupItems : []
        delegate: Region {
            required property var modelData
            // Overlay children use window-local coordinates. Keep the input
            // rectangle stable while the menu's opening scale animates.
            x: Math.floor(root.overlay.x + modelData.x)
            y: Math.floor(root.overlay.y + modelData.y)
            width: Math.ceil(modelData.width)
            height: Math.ceil(modelData.height)
        }
        onObjectAdded: (index, object) => root.regions.push(object)
        onObjectRemoved: (index, object) => {
            root.regions.length = 0
            for (let i = 0; i < count; i++) {
                const region = objectAt(i)
                if (region && region !== object) root.regions.push(region)
            }
        }
    }
}
