pragma ComponentBehavior: Bound
import QtQml
import "../../i18n"
import "../" as Services

// Independent menu state, presented by the existing picker controls/window.
QtObject {
    id: root
    property bool visible: false
    property bool hideForCapture: false
    readonly property int mode: Services.PickerService.Mode.Menu
    readonly property bool privateWindow: false
    property var targetScreen: null
    property string prompt: ""
    property string query: ""
    property string layout: "list"
    property string error: ""
    property string acceptLabel: Translations.text("common.actions.select")
    property string promptKey: ""
    readonly property bool previewImages: false
    readonly property bool imageOnly: false
    readonly property bool allowTyped: false
    readonly property bool multiple: false
    readonly property bool searchPending: false
    readonly property bool searchFailed: false
    readonly property string requestDirectory: ""
    readonly property var selectedIds: []
    property var items: []
    property int currentIndex: 0
    property var menuCallback: null
    property var menuClosedCallback: null
    property bool menuKeepOpen: false
    readonly property var filteredItems: Services.PickerService.filter(items, query)
    readonly property var currentItem: filteredItems[currentIndex] ?? null
    readonly property bool canAccept: !!currentItem
    signal opened()
    onQueryChanged: currentIndex = 0
    function menuRows(rows) { return Services.PickerService.menuRows(rows) }
    function promptMenu(title, rows, callback, presentation = "list", options = {}) {
        close("replaced", options.keepOpen === true)
        promptKey = options.promptKey ?? ""
        prompt = title; query = ""; error = ""; currentIndex = 0
        layout = presentation; items = menuRows(rows)
        menuCallback = callback; menuClosedCallback = options.onClosed ?? null
        menuKeepOpen = options.keepOpen === true
        acceptLabel = options.acceptLabel ?? Translations.text("common.actions.select")
        targetScreen = Services.PickerService.chooseScreen()
        visible = true
        opened()
    }
    function close(reason = "cancelled", keepVisible = false) {
        const closed = menuClosedCallback
        menuClosedCallback = null; menuCallback = null; menuKeepOpen = false
        if (!keepVisible) visible = false
        if (closed) closed(reason)
    }
    function move(delta) {
        if (filteredItems.length) currentIndex = (currentIndex + delta + filteredItems.length) % filteredItems.length
    }
    function select(index, _toggle = false) { currentIndex = index }
    function accept(_custom = false, _copyOnly = false) {
        if (!canAccept) return
        const selected = currentItem, callback = menuCallback, keepOpen = menuKeepOpen
        close("accepted", keepOpen)
        if (callback) callback([selected])
        if (keepOpen && !menuCallback) close()
    }
}
