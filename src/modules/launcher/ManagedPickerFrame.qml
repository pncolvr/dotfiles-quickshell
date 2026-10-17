pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../ui" as UI
import "../../services"

// Shared outer workflow; feature services still own management and draft state.
Item {
    id: root
    property var picker: PickerService
    property bool hideForCapture: false
    property bool backgroundVisible: true
    property bool adding: false
    required property int pickerMode
    required property bool managing
    required property string addSequence
    required property string manageSequence
    required property string showAllSequence
    required property bool addAllowed
    property bool nativeDialogOpen: false
    property bool manageDuringDialog: false
    required property Item headerItem
    required property PickerPanelBase listItem
    required property Item manageItem
    required property Item footerItem
    property var managementFocusTarget: null
    property var managementScroll: null
    property var managementView: null
    property var pendingScrollPositions: []
    required property UI.SearchField managementSearch
    readonly property bool sessionActive: visible && picker.visible && picker.mode === pickerMode
    readonly property real contentTop: headerItem.height + Theme.controlSpacing
    readonly property real listHeight: height - contentTop
    readonly property real manageHeight: Math.max(0, listHeight - (footerItem.visible ? footerItem.height + Theme.controlSpacing : 0))
    implicitWidth: managing ? Theme.manageWidth : Theme.pickerWidth
    implicitHeight: managing ? Theme.manageHeight : contentTop + listItem.implicitHeight
    signal managementRequested(bool value)
    signal addRequested()
    signal showAllRequested()
    signal escapeRequested()
    signal sessionClosed()

    function focusSearch() {
        if (!picker.visible) return
        const target = managing ? managementFocusTarget : listItem
        if (!target) return
        preserveManagementScroll(() => {
            if (typeof target.focusInput === "function") target.focusInput()
            else if (typeof target.focusSearch === "function") target.focusSearch()
            else target.forceActiveFocus()
        })
    }
    function preserveManagementScroll(action) {
        preserveScroll(action, managing ? managementScroll : null)
    }
    function preserveScroll(action, scroll) {
        if (scroll && !pendingScrollPositions.some(snapshot => snapshot.scroll === scroll))
            pendingScrollPositions = pendingScrollPositions.concat([{scroll, position: scroll.contentY}])
        action()
        if (pendingScrollPositions.length) Qt.callLater(root.restoreScrollPositions)
    }
    function restoreScrollPositions() {
        for (const snapshot of pendingScrollPositions) {
            const scroll = snapshot.scroll
            scroll.contentY = Math.max(scroll.originY, Math.min(snapshot.position,
                scroll.originY + Math.max(0, scroll.contentHeight - scroll.height)))
        }
        pendingScrollPositions = []
    }
    function management(value) {
        if (value === managing) return
        managementRequested(value)
        Qt.callLater(root.focusSearch)
    }
    function beginAdd() { addRequested(); Qt.callLater(root.focusSearch) }
    UI.PanelShortcut {
        owner: root
        configuredSequence: root.addSequence
        actionEnabled: root.sessionActive && root.addAllowed
        onActivated: root.beginAdd()
    }
    UI.PanelShortcut {
        owner: root
        configuredSequence: root.manageSequence
        actionEnabled: root.sessionActive && (root.manageDuringDialog || !root.nativeDialogOpen)
        onActivated: root.management(!root.managing)
    }
    UI.PanelShortcut {
        owner: root
        configuredSequence: root.showAllSequence
        actionEnabled: root.sessionActive && !root.managing && StatusService.enabled
        onActivated: root.showAllRequested()
    }
    Keys.onEscapePressed: root.escapeRequested()
    Connections {
        target: root.picker
        function onVisibleChanged() {
            if (!root.picker.visible) {
                root.sessionClosed()
                root.managementSearch.clear()
            }
        }
    }
}
