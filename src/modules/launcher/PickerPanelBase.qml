pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui" as UI
import "../../services"
import "../../config"

Rectangle {
    id: root
    property var picker: PickerService
    property bool hideForCapture: picker.hideForCapture ?? false
    property bool backgroundVisible: true
    property real placementWidth: implicitWidth
    property bool showThumbnails: true
    property bool compactImageRows: false
    property bool uniformRows: false
    property int maximumListRows: Config.pickerMaxRows
    readonly property bool gridMode: picker.layout === "grid"
    readonly property bool inputOnly: picker.mode === PickerService.Mode.Menu && picker.allowTyped && picker.items.length === 0
    readonly property var modulePointerTarget: search
    readonly property bool searchHasFocus: search.activeFocus
    property string searchPlaceholder: inputOnly ? picker.prompt : Translations.text("common.actions.search")
    property string panelError: picker.error
    property real minimumRowHeight: 0
    property int minimumListRows: 1
    property Component actionButtons: null
    property Component searchControls: null
    property real availableContentWidth: Theme.pickerWidth
    property real availableContentHeight: 800
    readonly property real columnWidth: Math.max(0, width - Theme.scrollbarGutter * 2)
    readonly property real normalHeight: panelHeader.height + list.implicitHeight + panelFooter.height
        + Theme.tooltipPaddingHeight + Theme.scrollbarGutter + Theme.controlSpacing
    property var searchKeyHandler: null
    property string hintPanel: "default"
    property var hintActions: ["search"]
    property var hintOverrides: ({})
    property string footerHint: ""
    property real openedListHeight: Theme.pickerRowHeight
    property bool awaitingOpeningRows: false
    readonly property real measuredRowHeight: Math.ceil(Math.max(minimumRowHeight,
        rowFont.height + Theme.pickerRowPadding * 2
            + (picker.items.some(item => !!item.subtitle) ? subtitleFont.height + 2 : 0)))
    implicitWidth: Theme.pickerWidth
    implicitHeight: normalHeight
    function focusSearch() { search.forceActiveFocus() }
    function sizeListForOpening() {
        const count = Math.max(1, Math.min(maximumListRows,
            picker.items.length || minimumListRows))
        openedListHeight = count * measuredRowHeight + (count - 1) * Theme.controlSpacing
    }
    onMaximumListRowsChanged: sizeListForOpening()
    FontMetrics {
        id: rowFont
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: Theme.fontBold
        font.styleName: Theme.fontStyle
        font.weight: Theme.fontWeight
        font.hintingPreference: Theme.fontHintingPreference
    }
    FontMetrics {
        id: subtitleFont
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        font.bold: Theme.fontBold
        font.styleName: Theme.fontStyle
        font.weight: Theme.fontWeight
        font.hintingPreference: Theme.fontHintingPreference
    }
    function acceptSelection(modifiers) { picker.accept((modifiers & Qt.ControlModifier) !== 0, false) }
    function handleSelectionKey(event, activate) {
        if (!picker.multiple) return false
        if (UI.Keybinds.matches(event,"selection.toggle") || (event.key === Qt.Key_Space && !event.modifiers && !searchHasFocus)) {
            if (activate) { picker.select(picker.currentIndex,true); picker.move(1) }
        } else if (UI.Keybinds.matches(event,"selection.clear") || (UI.Keybinds.matches(event,"selection.all") && !searchHasFocus)) {
            if (activate) {
                if (UI.Keybinds.matches(event,"selection.clear")) picker.deselectAll()
                else picker.toggleVisibleSelection()
            }
        } else return false
        return true
    }
    Connections {
        target: root.picker
        function onOpened() {
            search.text = root.picker.query
            root.awaitingOpeningRows = root.picker.items.length === 0
            root.sizeListForOpening()
            Qt.callLater(root.focusSearch)
        }
        function onItemsChanged() {
            if (!root.awaitingOpeningRows || !root.picker.visible || !root.picker.items.length) return
            root.awaitingOpeningRows = false
            root.sizeListForOpening()
        }
        function onVisibleChanged() {
            if (root.picker.visible) return
            root.awaitingOpeningRows = false
            search.resetSearch()
        }
    }

    radius: Theme.tooltipRadius
    color: backgroundVisible ? Qt.rgba(Theme.tooltipBackground.r, Theme.tooltipBackground.g, Theme.tooltipBackground.b,
        Theme.tooltipBackground.a * Math.max(0, Math.min(1, Theme.pickerBackgroundOpacity))) : "transparent"
    FocusScope {
        anchors.fill: parent
        anchors.margins: Theme.tooltipPaddingHeight
        anchors.leftMargin: Theme.scrollbarGutter
        anchors.rightMargin: Theme.scrollbarGutter
        anchors.bottomMargin: Theme.scrollbarGutter
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.forwardTo: [root]
        Keys.onPressed: event => {
            if (UI.Keybinds.handleCancel(event, () => root.picker.close())) return
            switch (event.key) {
                case Qt.Key_Down: root.picker.move(1); break
                case Qt.Key_Up: root.picker.move(-1); break
                case Qt.Key_Left: if (!root.gridMode) { event.accepted = false; return } root.picker.move(-1); break
                case Qt.Key_Right: if (!root.gridMode) { event.accepted = false; return } root.picker.move(1); break
                case Qt.Key_PageDown: root.picker.move(Config.pickerMaxRows); break
                case Qt.Key_PageUp: root.picker.move(-Config.pickerMaxRows); break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.acceptSelection(event.modifiers)
                    break
                default: event.accepted = false; return
            }
            event.accepted = true
        }
        Column {
            id: panelHeader
            width: root.columnWidth
            spacing: Theme.controlSpacing
            UI.SearchField {
                id: search
                objectName: "pickerSearch"
                width: parent.width
                placeholderText: root.searchPlaceholder
                retainPanelWhileEditing: false
                resetWithTooltip: false
                handleEscape: false
                readOnly: root.picker.menuBusy ?? false
                Keys.onShortcutOverride: event => {
                    if (root.searchKeyHandler && root.searchKeyHandler(event,false)) event.accepted = true
                }
                onTextChanged: root.picker.query = text
                Keys.priority: Keys.BeforeItem
                Keys.forwardTo: [root]
                Keys.onPressed: event => {
                    if (root.searchKeyHandler && root.searchKeyHandler(event,true)) { event.accepted = true; return }
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter || UI.Keybinds.matches(event, "cancel") || event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) event.accepted = false
                }
            }
            Loader { width: parent.width; height: (item as Item)?.implicitHeight ?? 0; visible: !root.inputOnly || sourceComponent !== null; sourceComponent: root.searchControls }
            UI.Text {
                centerVertical: false
                width: parent.width
                height: visible ? Theme.controlHeight : 0
                visible: (Config.pickerShowPrompt || root.picker.forcePrompt) && root.picker.prompt.length > 0
                verticalAlignment: Text.AlignVCenter
                text: root.picker.prompt
                textFormat: Text.PlainText
            }
            UI.Text {
                centerVertical: false
                width: parent.width
                text: root.panelError
                visible: text.length > 0
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.warning
            }
        }
        UI.PickerList {
            id: list
            objectName: "pickerList"
            picker: root.picker
            showThumbnails: root.showThumbnails
            compactImages: root.compactImageRows
            rowHeight: root.uniformRows ? root.measuredRowHeight : 0
            // Rows align with the header; the viewport reaches into the outer
            // padding so the scrollbar has its own strip beside the content.
            x: root.gridMode ? 0 : -Theme.scrollbarGutter
            width: root.gridMode ? root.columnWidth : root.columnWidth + Theme.scrollbarGutter * 2
            y: panelHeader.height + Theme.controlSpacing
            visible: !root.inputOnly
            height: root.inputOnly ? 0 : Math.max(0, panelFooter.y - y)
            // Keep the opening size while filtering or deleting entries so the
            // panel and its footer do not move under keyboard focus.
            implicitHeight: root.inputOnly ? 0 : root.gridMode
                ? Theme.pickerGridHeight + list.horizontalGutter * 2 : root.openedListHeight
        }
        UI.Text {
            objectName: "pickerEmptyHint"
            centerVertical: false
            anchors.centerIn: list
            visible: list.count === 0 && !root.inputOnly
            text: root.inputOnly ? "" : Translations.text(root.picker.allowTyped && search.text.length ? "picker.empty.useTyped" : "picker.empty.results")
            textFormat: Text.PlainText
            color: Theme.inactive
        }
        Item {
            id: panelFooter
            objectName: "pickerFooter"
            width: parent.width
            implicitHeight: actions.height + (actions.visible ? Theme.controlSpacing * 2 : 0) + hints.height
            height: implicitHeight
            anchors.bottom: parent.bottom
            Loader {
                id: actions
                objectName: "pickerFooterActions"
                anchors.right: parent.right
                width: parent.width
                height: (item as Item)?.implicitHeight ?? 0
                y: visible ? Theme.controlSpacing : 0
                visible: sourceComponent !== null
                sourceComponent: root.actionButtons
            }
            UI.ShortcutHints {
                id: hints
                objectName: "pickerFooterHint"
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                y: actions.y + actions.height + (actions.visible ? Theme.controlSpacing : 0)
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                hints: root.footerHint
                panelKey: root.hintPanel
                availableActions: root.hintActions
                actionOverrides: root.hintOverrides
            }
        }
    }
}
