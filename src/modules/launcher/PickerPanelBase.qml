pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"

Rectangle {
    id: root
    property var picker: PickerService
    property bool backgroundVisible: true
    readonly property bool gridMode: picker.layout === "grid"
    readonly property bool searchHasFocus: search.activeFocus
    property string searchPlaceholder: "Search"
    property string panelError: picker.error
    property real minimumRowHeight: 0
    property int minimumListRows: 1
    property Component actionButtons: null
    property var searchKeyHandler: null
    property string footerHint: gridMode ? "Arrows to select · Enter to choose · Esc to cancel"
        : "Arrows to select · Enter to " + picker.acceptLabel.toLowerCase() + " · Esc to cancel"
    property real openedListHeight: Theme.pickerRowHeight
    implicitWidth: Theme.pickerWidth
    implicitHeight: header.height + list.implicitHeight + footer.height + Theme.tooltipPaddingHeight * 2 + 12
    function focusSearch() { search.forceActiveFocus() }
    function sizeListForOpening() {
        const count = Math.max(1, Math.min(Config.pickerMaxRows,
            picker.items.length || minimumListRows))
        const hasSubtitle = picker.items.some(item => !!item.subtitle)
        const textHeight = rowFont.height + Theme.pickerRowPadding * 2
            + (hasSubtitle ? subtitleFont.height + 2 : 0)
        const rowHeight = Math.max(textHeight, minimumRowHeight)
        openedListHeight = count * rowHeight + (count - 1) * Theme.controlSpacing
    }
    FontMetrics {
        id: rowFont
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: Theme.fontBold
        font.styleName: Theme.fontStyle
        font.weight: Theme.fontWeight
    }
    FontMetrics {
        id: subtitleFont
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        font.bold: Theme.fontBold
        font.styleName: Theme.fontStyle
        font.weight: Theme.fontWeight
    }
    function acceptSelection(modifiers) { picker.accept((modifiers & Qt.ControlModifier) !== 0, false) }
    function handleSelectionKey(event, activate) {
        if (!picker.multiple) return false
        if (event.key === Qt.Key_Space) {
            if (searchHasFocus && !(event.modifiers & Qt.ShiftModifier)) return false
            if (activate) { picker.select(picker.currentIndex,true); picker.move(1) }
        } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            if (activate) {
                if (event.modifiers & Qt.ShiftModifier) picker.deselectAll()
                else picker.toggleVisibleSelection()
            }
        } else return false
        return true
    }
    Connections {
        target: root.picker
        function onOpened() {
            search.text = root.picker.query
            root.sizeListForOpening()
            Qt.callLater(root.focusSearch)
        }
        function onVisibleChanged() { if (!root.picker.visible) search.resetSearch() }
    }

    radius: Theme.tooltipRadius
    color: backgroundVisible ? Qt.rgba(Theme.tooltipBackground.r, Theme.tooltipBackground.g, Theme.tooltipBackground.b,
        Theme.tooltipBackground.a * Math.max(0, Math.min(1, Theme.pickerBackgroundOpacity))) : "transparent"
    FocusScope {
        anchors.fill: parent
        anchors.margins: Theme.tooltipPaddingHeight
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.forwardTo: [root]
        Keys.onPressed: event => {
            switch (event.key) {
                case Qt.Key_Escape: root.picker.close(); break
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
            id: header
            width: parent.width
            spacing: Theme.controlSpacing
            UI.SearchField {
                id: search
                objectName: "pickerSearch"
                width: parent.width
                placeholderText: root.searchPlaceholder
                pauseTooltipDismissal: false
                resetWithTooltip: false
                handleEscape: false
                Keys.onShortcutOverride: event => {
                    if (root.searchKeyHandler && root.searchKeyHandler(event,false)) event.accepted = true
                }
                onTextChanged: root.picker.query = text
                Keys.priority: Keys.BeforeItem
                Keys.forwardTo: [root]
                Keys.onPressed: event => {
                    if (root.searchKeyHandler && root.searchKeyHandler(event,true)) { event.accepted = true; return }
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape || event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) event.accepted = false
                }
            }
            UI.Text {
                centerVertical: false
                width: parent.width
                height: visible ? Theme.controlHeight : 0
                visible: Config.pickerShowPrompt && root.picker.prompt.length > 0
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
            width: parent.width
            y: header.height + Theme.controlSpacing
            height: Math.max(0, footer.y - y - Theme.controlSpacing)
            // Keep the opening size while filtering or deleting entries so the
            // panel and its footer do not move under keyboard focus.
            implicitHeight: root.gridMode ? Theme.pickerGridHeight : root.openedListHeight
        }
        UI.Text {
            centerVertical: false
            anchors.centerIn: list
            visible: list.count === 0
            text: root.picker.allowTyped && search.text.length ? "Enter to use typed input" : "No results"
            color: Theme.inactive
        }
        Column {
            id: footer
            width: parent.width
            anchors.bottom: parent.bottom
            spacing: Theme.controlSpacing
            Loader {
                width: parent.width
                height: (item as Item)?.implicitHeight ?? 0
                visible: sourceComponent !== null
                sourceComponent: root.actionButtons
            }
            UI.ShortcutHints {
                objectName: "pickerFooterHint"
                width: parent.width
                hints: root.footerHint
            }
        }
    }
}
