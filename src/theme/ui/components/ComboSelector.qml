pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QC
import "../../"
import "../" as UI

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
    property real controlHeight: Theme.controlHeight
    property real contentPadding: Theme.controlFieldPadding
    property real optionRowHeight: compact ? controlHeight + Theme.controlSpacing : controlHeight * 2
    property int maxVisibleRows: 5
    property real spacing: Theme.controlSpacing
    property bool expanded: false
    property string toggleObjectName: "selectorToggle"
    property string choicesObjectName: "selectorChoices"
    property alias choicesView: choices
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
    function contentBounds(): Item {
        for (let item = root.parent; item; item = item.parent) {
            const bounds = hostBounds(item)
            if (bounds) return bounds
        }
        return selectionPopup.parent
    }
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
        const desired = Math.min(root.options.length, root.maxVisibleRows) * root.optionRowHeight + selectionPopup.padding * 2
        const opensAbove = below < desired && above > below
        selectionPopup.width = Math.max(0, Math.min(root.width, right - left))
        selectionPopup.height = Math.min(desired, Math.max(0, opensAbove ? above : below))
        selectionPopup.x = Math.round(Math.max(left, Math.min(control.x, right - selectionPopup.width)))
        const idealY = opensAbove ? control.y - root.spacing - selectionPopup.height : control.y + root.height + root.spacing
        selectionPopup.y = Math.round(Math.max(top, Math.min(idealY, bottom - selectionPopup.height)))
        selectionPopup.transformOrigin = opensAbove ? Item.Bottom : Item.Top
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
    QC.Button {
        id: selector
        visible: !root.readOnly
        UI.PointerFocus {}
        objectName: root.toggleObjectName
        width: parent.width
        implicitHeight: root.compact ? root.controlHeight
            : Math.max(root.controlHeight, currentLabel.implicitHeight + root.contentPadding * 2)
        padding: root.contentPadding
        hoverEnabled: true
        opacity: enabled ? 1 : 0.5
        Accessible.name: root.hint || root.label
        onClicked: root.expanded = !root.expanded
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) { root.expanded = true; event.accepted = true }
        }
        background: Rectangle {
            color: selector.hovered ? Theme.selectionHoverBackground : Theme.selectionBackground
            radius: Theme.iconButtonRadius
            border.width: 1
            border.color: selector.visualFocus || root.expanded ? Theme.accent : Theme.selectionBorder
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
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    QC.Popup {
        id: selectionPopup
        parent: QC.Overlay.overlay
        enabled: root.expanded
        popupType: QC.Popup.Item
        padding: Theme.selectionPopupPadding
        modal: false
        dim: false
        focus: true
        margins: 0
        closePolicy: QC.Popup.CloseOnEscape | QC.Popup.CloseOnPressOutside
        onAboutToShow: { root.placePopup(); choices.revealSelected() }
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
        contentItem: UI.SelectionList {
            id: choices
            focus: true
            objectName: root.choicesObjectName
            options: root.options
            selectedName: root.selectedName
            rowHeight: root.optionRowHeight
            contentPadding: root.contentPadding
            wrapDescriptions: !root.compact
            onSelected: name => { root.expanded = false; if (name !== root.selectedName) root.selected(name) }
        }
    }
}
