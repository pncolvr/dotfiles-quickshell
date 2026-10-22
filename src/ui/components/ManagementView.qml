pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import ".." as UI

Item {
    id: root
    property var entries: []
    property var searchEntries: (items, query) => items.filter(entry =>
        (entry.search ?? entry.title).toLowerCase().includes(query.toLowerCase()))
    property bool editing: false
    property bool busy: false
    property bool showCategory: false
    property bool filterEnabled: false
    property var browserOptions: []
    property var typeOptions: []
    property bool filterAvailability: false
    property string category: ""
    property var filterValues: ({})
    property string selectedId: ""
    property string searchPlaceholder: ""
    property string searchObjectName: "managementSearch"
    property string addObjectName: "managementAdd"
    property string listObjectName: "managementList"
    property string addHint: Translations.text("manage.actions.newEntry")
    readonly property bool editEnabled: visible && !!selectedEntry && !editing && !busy
    signal editRequested()
    property string message: ""
    property string hints: ""
    property bool refreshHintEnabled: false
    property var hintOverrides: ({})
    property alias searchField: search
    property alias query: search.text
    property alias listView: list
    property alias detailScroll: details
    property alias detailContent: detailBody.data
    property alias actionContent: actions.data
    property alias toolbarContent: toolbarExtras.data
    readonly property var selectedEntry: filteredEntries.find(entry => entry.id === selectedId) ?? null
    readonly property var filteredEntries: {
        const candidates = entries.filter(entry => (!showCategory || !category || entry.category === category)
            && filterDefinitions.every(filter => !filterValues[filter.key] || String(entry[filter.key]) === filterValues[filter.key]))
        return searchEntries(candidates, search.text)
    }
    readonly property var filterDefinitions: {
        const all = {name:"", description:Translations.text("common.filters.all")}
        const filters = []
        if (showCategory) filters.push({key:"category",label:Translations.text("manage.filter.category"),options:[all,
            {name:"personal",description:Translations.text("status.modes.personal")},
            {name:"work",description:Translations.text("status.modes.work")}]})
        if (filterEnabled) filters.push({key:"enabled", label:Translations.text("manage.filter.state"), options:[all,
            {name:"true",description:Translations.text("common.states.enabled")}, {name:"false",description:Translations.text("common.states.disabled")}]})
        if (browserOptions.length) filters.push({key:"browser",label:Translations.text("manage.filter.browser"),options:[all,...browserOptions]})
        if (typeOptions.length) filters.push({key:"type",label:Translations.text("manage.filter.type"),options:[all,...typeOptions]})
        if (filterAvailability) filters.push({key:"availability",label:Translations.text("manage.filter.availability"),options:[all,
            {name:"available",description:Translations.text("manage.states.available")},
            {name:"unavailable",description:Translations.text("common.states.unavailable")},
            {name:"unchecked",description:Translations.text("files.status.unchecked")}]})
        return filters
    }
    signal addRequested()
    implicitHeight: Theme.manageHeight
    onFilteredEntriesChanged: {
        if (!filteredEntries.some(entry => entry.id === selectedId)) selectedId = filteredEntries[0]?.id ?? ""
    }
    onEditingChanged: details.contentY = 0
    function focusInput() { if (!editing) search.forceActiveFocus() }
    function select(entryId) {
        if (editing) return
        selectSaved(entryId)
    }
    function selectSaved(entryId) {
        selectedId = filteredEntries.some(entry => entry.id === entryId) ? entryId : filteredEntries[0]?.id ?? ""
        details.contentY = 0
    }
    function moveSelection(delta) {
        const index = filteredEntries.findIndex(entry => entry.id === selectedId)
        select(filteredEntries[Math.max(0, Math.min(filteredEntries.length - 1, index + delta))]?.id ?? "")
        list.positionViewAtIndex(Math.max(0, filteredEntries.findIndex(entry => entry.id === selectedId)), ListView.Contain)
    }
    UI.PanelShortcut {
        owner: root
        action: "edit"
        actionEnabled: root.editEnabled
        onActivated: root.editRequested()
    }
    Column {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.projectManagePadding
        anchors.bottomMargin: footerHints.height
        spacing: Theme.controlSpacing
        Item {
            width: parent.width
            height: Theme.controlHeight
            UI.SearchField {
                id: search
                objectName: root.searchObjectName
                anchors.left: parent.left
                anchors.right: toolbarActions.left
                anchors.rightMargin: Theme.controlSpacing
                enabled: !root.editing
                placeholderText: root.searchPlaceholder
                retainPanelWhileEditing: false
                resetWithTooltip: false
                handleEscape: false
                onTextChanged: root.select(root.filteredEntries[0]?.id ?? "")
                Keys.onPressed: event => {
                    event.accepted = false
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                        root.moveSelection(event.key === Qt.Key_Down ? 1 : -1)
                        event.accepted = true
                    }
                }
            }
            Row {
                id: toolbarActions
                anchors.right: parent.right
                spacing: Theme.controlSpacing
                Row {
                    id: toolbarExtras
                    visible: children.length > 0
                    spacing: Theme.controlSpacing
                }
                UI.ActionButton {
                    objectName: root.addObjectName
                    glyph: Theme.addIcon
                    hint: root.addHint
                    enabled: !root.busy && !root.editing
                    onClicked: root.addRequested()
                }
            }
        }
        Row {
            id: filters
            width: parent.width
            visible: root.filterDefinitions.length > 0
            spacing: Theme.controlSpacing
            Repeater {
                model: root.filterDefinitions
                delegate: UI.ComboSelector {
                    required property var modelData
                    width: (filters.width - filters.spacing * (root.filterDefinitions.length - 1)) / root.filterDefinitions.length
                    enabled: !root.editing
                    compact: true
                    options: modelData.options
                    selectedName: modelData.key === "category" ? root.category : root.filterValues[modelData.key] ?? ""
                    label: Translations.text("manage.filter.label",[modelData.label,selectedDescription])
                    objectName: modelData.key === "category" ? "managementCategory" : "managementFilter-" + modelData.key
                    onSelected: name => {
                        if (modelData.key === "category") root.category = name
                        else root.filterValues = Object.assign({},root.filterValues,{[modelData.key]:name})
                        root.select(root.filteredEntries[0]?.id ?? "")
                    }
                }
            }
        }
        Row {
            width: parent.width
            height: Math.max(0, content.height - y - (feedback.visible ? feedback.height + content.spacing : 0))
            spacing: Theme.controlSpacing * 2
            ListView {
                id: list
                property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: list }
                activeFocusOnTab: true
                keyNavigationEnabled: false
                objectName: root.listObjectName
                width: parent.width * 0.38
                height: parent.height
                clip: true
                model: root.filteredEntries
                enabled: !root.editing
                currentIndex: root.filteredEntries.findIndex(entry => entry.id === root.selectedId)
                boundsBehavior: Flickable.StopAtBounds
                topMargin: Theme.controlSpacing
                bottomMargin: Theme.controlSpacing
                QC.ScrollBar.vertical: UI.ScrollBar {}
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                        root.moveSelection(event.key === Qt.Key_Down ? 1 : -1)
                        event.accepted = true
                    }
                }
                Rectangle { anchors.fill: parent; anchors.margins: 1; z: 1; color: "transparent"; radius: Theme.iconButtonRadius; border.width: 1; border.color: list.activeFocus ? Theme.accent : Theme.empty }
                delegate: UI.SelectableRow {
                    id: row
                    focusPolicy: Qt.NoFocus
                    required property var modelData
                    required property int index
                    width: list.width
                    leftPadding: Theme.controlFieldPadding + Theme.scrollbarGutter
                    rightPadding: Theme.controlFieldPadding + Theme.scrollbarGutter
                    height: Theme.manageRowHeight
                    objectName: "managementEntry-" + modelData.id
                    current: index === list.currentIndex
                    onActivated: root.select(modelData.id)
                    contentItem: Column {
                        UI.ColumnText { width: parent.width; text: row.modelData.title; textFormat: Text.PlainText; elide: Text.ElideMiddle; color: row.foreground }
                        UI.ColumnText { width: parent.width; text: row.modelData.subtitle ?? ""; textFormat: Text.PlainText; elide: Text.ElideMiddle; color: row.secondaryForeground }
                    }
                }
                UI.ColumnText { anchors.centerIn: parent; width: parent.width - Theme.controlFieldPadding * 2; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; text: Translations.text("collections.empty.filtered"); visible: !root.filteredEntries.length }
            }
            Item {
                width: parent.width - list.width - parent.spacing
                height: parent.height
                Rectangle { anchors.fill: parent; anchors.margins: 1; z: 1; color: "transparent"; radius: Theme.iconButtonRadius; border.width: 1; border.color: Theme.empty }
                Flickable {
                    id: details
                    property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: details }
                    objectName: "managementDetailsScroll"
                    x: Theme.controlSpacing
                    y: Theme.controlSpacing
                    width: parent.width - Theme.controlSpacing * 2
                    height: Math.max(0, parent.height - y - actions.height - Theme.controlSpacing * 2)
                    contentWidth: width
                    contentHeight: detailBody.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    QC.ScrollBar.vertical: UI.ScrollBar {}
                    Column { id: detailBody; x: Theme.scrollbarGutter; width: Math.max(0, details.width - Theme.scrollbarGutter * 2); spacing: Theme.controlSpacing }
                }
                Row {
                    id: actions
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: Theme.controlSpacing
                    spacing: Theme.controlSpacing
                }
            }
        }
        UI.ColumnText {
            id: feedback
            width: parent.width
            visible: !!root.message
            text: root.message
            textFormat: Text.PlainText
            color: Theme.warning
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSize - 1
        }
    }
    UI.ShortcutHints {
        id: footerHints
        objectName: "managementHints"
        x: Theme.projectManagePadding
        width: parent.width - Theme.projectManagePadding * 2
        anchors.bottom: parent.bottom
        actionOverrides: root.hintOverrides
        panelKey: root.editing ? "editing" : "manage"
        availableActions: root.editing ? (root.busy ? [] : ["save"]) : ["search", "manage"].concat(root.editEnabled ? ["edit"] : [])
            .concat(!root.busy ? ["add"] : []).concat(root.refreshHintEnabled ? ["refresh"] : [])
    }
}
