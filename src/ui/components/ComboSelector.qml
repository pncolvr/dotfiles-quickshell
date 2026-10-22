pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QC
import "../../theme"
import ".." as UI

Item {
    id: root
    property var options: []
    property string selectedName: ""
    property string placeholder: Translations.text("common.actions.chooseOption")
    property string label: selectedDescription
    property string hint: ""
    property int hintDelay: 500
    property bool readOnly: false
    property bool compact: false
    property bool searchable: false
    readonly property var filteredOptions: !searchable || !search.query ? options
        : options.filter(option => (option.description + ' ' + option.name).toLowerCase().includes(search.query))
    property real controlHeight: Theme.controlHeight
    property real contentPadding: Theme.controlFieldPadding
    property real optionRowHeight: compact ? controlHeight + Theme.controlSpacing : controlHeight * 2
    property int maxVisibleRows: 5
    property real spacing: Theme.controlSpacing
    property bool expanded: false
    property string toggleObjectName: "selectorToggle"
    property string choicesObjectName: "selectorChoices"
    property alias choicesView: choices
    property alias searchInput: search
    property alias popup: selectionPopup
    readonly property string selectedDescription: options.find(option => option.name === selectedName)?.description ?? placeholder
    readonly property var nativeWindow: root.Window.window
    readonly property Flickable scrollHost: findScrollHost()
    signal selected(string name)
    implicitHeight: selector.implicitHeight
    onReadOnlyChanged: if (readOnly) expanded = false
    onEnabledChanged: if (!enabled) expanded = false
    onVisibleChanged: if (!visible) expanded = false
    onExpandedChanged: {
        if (expanded && enabled && visible && !readOnly && options.length) {
            selector.forceActiveFocus(Qt.PopupFocusReason)
            selectionPopup.open()
        }
        else { expanded = false; selectionPopup.close() }
    }
    onOptionsChanged: if (expanded) {
        if (!options.length) expanded = false
        else Qt.callLater(placePopup)
    }
    onWidthChanged: if (expanded) placePopup()
    onHeightChanged: if (expanded) placePopup()
    function findScrollHost(): Flickable {
        for (let item = root.parent; item; item = item.parent) {
            if (item instanceof Flickable) return item as Flickable
        }
        return null
    }
    function hostBounds(item: var): Item { return item.popupContentBounds ?? null }
    function panelBounds(): Item {
        for (let item = root.parent; item; item = item.parent) {
            const bounds = hostBounds(item)
            if (bounds) return bounds
        }
        return QC.Overlay.overlay
    }
    function contentBounds(): Item { return QC.Overlay.overlay ?? panelBounds() }
    function placePopup() {
        if (!selectionPopup.parent) return
        const bounds = contentBounds()
        const corner = bounds.mapToItem(selectionPopup.parent, 0, 0)
        const control = root.mapToItem(selectionPopup.parent, 0, 0)
        const margin = Theme.selectionPopupPadding
        const left = corner.x + margin
        const top = corner.y + margin
        const right = corner.x + bounds.width - margin
        const bottom = corner.y + bounds.height - margin
        const below = Math.max(0, bottom - control.y - root.height - root.spacing)
        const above = Math.max(0, control.y - root.spacing - top)
        const searchHeight = root.searchable ? search.implicitHeight + root.spacing : 0
        const desired = Math.max(1, Math.min(root.filteredOptions.length, root.maxVisibleRows)) * root.optionRowHeight
            + searchHeight + selectionPopup.padding * 2
        const opensAbove = below < desired && above > below
        selectionPopup.width = Math.max(0, Math.min(root.width, right - left))
        selectionPopup.height = Math.min(desired, Math.max(0, opensAbove ? above : below))
        selectionPopup.x = Math.round(Math.max(left, Math.min(control.x, right - selectionPopup.width)))
        const idealY = opensAbove ? control.y - root.spacing - selectionPopup.height : control.y + root.height + root.spacing
        selectionPopup.y = Math.round(Math.max(top, Math.min(idealY, bottom - selectionPopup.height)))
        selectionPopup.transformOrigin = opensAbove ? Item.Bottom : Item.Top
    }
    Connections {
        // The native buffer stays fixed while the visible panel changes size.
        target: root.expanded ? root.panelBounds() : null
        function onWidthChanged() { root.placePopup() }
        function onHeightChanged() { root.placePopup() }
    }
    Connections {
        target: root.nativeWindow
        function onVisibleChanged() { if (!root.nativeWindow.visible) root.expanded = false }
        function onWidthChanged() { if (root.expanded) root.placePopup() }
        function onHeightChanged() { if (root.expanded) root.placePopup() }
    }
    Connections {
        target: root.scrollHost
        ignoreUnknownSignals: true
        function onContentXChanged() { root.expanded = false }
        function onContentYChanged() { root.expanded = false }
        function onMovingChanged() { if (root.scrollHost.moving) root.expanded = false }
    }
    UI.InputField {
        width: parent.width
        visible: root.readOnly
        readOnly: true
        text: root.label
        retainPanelWhileEditing: false
    }
    UI.Button {
        id: selector
        visible: !root.readOnly
        objectName: root.toggleObjectName
        width: parent.width
        implicitHeight: root.compact ? root.controlHeight
            : Math.max(root.controlHeight, currentLabel.implicitHeight + root.contentPadding * 2)
        padding: root.contentPadding
        opacity: enabled ? 1 : 0.5
        fillColor: Theme.selectionBackground
        hoverColor: Theme.selectionHoverBackground
        pressedColor: Qt.darker(Theme.selectionHoverBackground, 1.2)
        Accessible.name: root.hint || root.label
        onClicked: root.expanded = !root.expanded
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) { root.expanded = true; event.accepted = true }
        }
        background: UI.ButtonSurface {
            control: selector
            fillColor: selector.fillColor
            hoverColor: selector.hoverColor
            pressedColor: selector.pressedColor
            border.width: 1
            border.color: selector.keyboardFocusVisible || root.expanded ? Theme.accent : Theme.selectionBorder
        }
        contentItem: Item {
            UI.ColumnText {
                id: currentLabel
                width: parent.width - arrow.width - root.spacing
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.label
                wrapMode: root.compact ? Text.NoWrap : Text.Wrap
                elide: root.compact ? Text.ElideRight : Text.ElideNone
            }
            UI.IconText {
                id: arrow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.chevronDownIcon
                rotation: root.expanded ? 180 : 0
                color: root.expanded ? Theme.accent : Theme.inactive
            }
        }
        UI.HoverTooltip { hoverTarget: selector; text: root.expanded ? "" : root.hint; delay: root.hintDelay }
    }
    QC.Popup {
        id: selectionPopup
        // Parent the popup to its trigger while Popup.Item still renders it in
        // the window overlay. An outside press on the trigger must reach its
        // toggle without first auto-closing and then reopening the popup.
        parent: selector
        enabled: root.expanded
        popupType: QC.Popup.Item
        padding: Theme.selectionPopupPadding
        modal: false
        dim: false
        focus: true
        margins: 0
        closePolicy: QC.Popup.CloseOnPressOutsideParent
        onAboutToShow: { search.clear(); root.placePopup(); choices.revealSelected() }
        onOpened: if (root.searchable) search.forceActiveFocus(Qt.PopupFocusReason)
        onClosed: root.expanded = false
        enter: Transition {
            UI.MotionAnimation { property: "opacity"; from: 0; to: 1; animationDuration: Theme.selectionAnimationDuration }
            UI.MotionAnimation { property: "scale"; from: 0.98; to: 1; animationDuration: Theme.selectionAnimationDuration; easing.type: Easing.OutCubic }
        }
        // Popup.Item keeps filtering input during an exit transition. Close
        // immediately so a second click reaches the newly uncovered control.
        exit: Transition {}
        background: Rectangle {
            color: Theme.selectionBackground
            radius: Theme.iconButtonRadius
            border.width: 1
            border.color: Theme.selectionBorder
        }
        contentItem: Item {
            // The host adds this menu to its input region while it is visible.
            readonly property QC.Popup panelPopup: selectionPopup
            UI.SearchField {
                id: search
                width: parent.width
                visible: root.searchable
                placeholderText: Translations.text("common.actions.search")
                resetWithTooltip: false
                handleEscape: false
                property bool blocksPanelShortcuts: true
                onQueryChanged: if (root.expanded) Qt.callLater(() => { root.placePopup(); choices.revealSelected() })
                onAccepted: choices.activateCurrent()
                Keys.onPressed: event => {
                    if (UI.Keybinds.handleCancel(event, () => { root.expanded = false })) return
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                        choices.forceActiveFocus(Qt.TabFocusReason)
                        choices.navigate(event.key === Qt.Key_Down ? 1 : -1, true)
                        event.accepted = true
                    }
                }
            }
            UI.SelectionList {
                id: choices
                anchors.fill: parent
                anchors.topMargin: root.searchable ? search.height + root.spacing : 0
                cancelHandler: () => { root.expanded = false }
                focus: true
                objectName: root.choicesObjectName
                options: root.filteredOptions
                selectedName: root.selectedName
                rowHeight: root.optionRowHeight
                contentPadding: root.contentPadding
                wrapDescriptions: !root.compact
                onSelected: name => { root.expanded = false; if (name !== root.selectedName) root.selected(name) }
            }
        }
    }
}
