import QtQuick
import QtQuick.Window
import "../services"

Item {
    id: root
    required property var tooltipWindow
    readonly property var nativeWindow: tooltipWindow.contentItem.Window.window
    readonly property bool pending: BarModuleService.pointerReady && tooltipWindow.visible
        && BarModuleService.pointerItem === TooltipService.source
        && tooltipWindow.screen === TooltipService.screen
    visible: false
    onPendingChanged: if (pending) nativeWindow?.update()

    Connections {
        target: root.nativeWindow
        function onFrameSwapped() {
            if (root.pending) BarModuleService.finishPointerMove()
        }
    }
}
