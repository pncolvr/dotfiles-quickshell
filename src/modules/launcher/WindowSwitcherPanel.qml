pragma ComponentBehavior: Bound
import QtQuick
import "../../i18n"
import "../../theme"
import "../../theme/ui" as UI

PickerPanelBase {
    id: root
    property bool previewEnabled: false
    property real previewProgress: 0
    readonly property bool motionEnabled: UI.MotionPolicy.enabled
    readonly property bool transitioning: previewProgress !== (previewEnabled ? 1 : 0)
    readonly property bool sideBySide: availableContentWidth >= Theme.pickerWidth + 240
    implicitWidth: Math.min(Theme.pickerWidth,availableContentWidth)
        + (sideBySide ? Math.max(0,availableContentWidth - Theme.pickerWidth) * previewProgress : 0)
    implicitHeight: normalHeight + (Math.max(normalHeight,availableContentHeight) - normalHeight) * previewProgress
    fixedListWidth: sideBySide && previewProgress > 0 ? Theme.pickerWidth - Theme.tooltipPaddingHeight * 2 : 0
    stackedPreview: !sideBySide && previewProgress > 0
    previewOpacity: previewProgress
    showThumbnails: false
    footerHint: Translations.text("picker.shortcuts.windowSwitch")
    searchKeyHandler: (event, activate) => {
        if (event.key === Qt.Key_I && event.modifiers === (Qt.ControlModifier | Qt.ShiftModifier)) {
            if (activate) root.previewEnabled = !root.previewEnabled
            return true
        }
        if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && (event.modifiers & Qt.AltModifier)) {
            if (activate) root.picker.cycleWindowSwitch((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
            return true
        }
        return false
    }
    function transition() {
        previewMotion.stop()
        if (!picker.visible) { previewProgress = 0; return }
        if (motionEnabled) { previewMotion.to = previewEnabled ? 1 : 0; previewMotion.restart() }
        else previewProgress = previewEnabled ? 1 : 0
    }
    onPreviewEnabledChanged: transition()
    onMotionEnabledChanged: transition()
    UI.MotionAnimation { id: previewMotion; target: root; property: "previewProgress"; animationDuration: Theme.clipboardLayoutDuration; easing.type: Easing.OutCubic }
    Connections {
        target: root.picker
        function onVisibleChanged() {
            if (!root.picker.visible) { previewMotion.stop(); root.previewEnabled = false; root.previewProgress = 0 }
        }
    }
    previewComponent: previewProgress > 0 ? windowPreview : null
    Component {
        id: windowPreview
        WindowPreview {
            client: root.picker.currentItem?.client ?? ({address:"",class:""})
        }
    }
}
