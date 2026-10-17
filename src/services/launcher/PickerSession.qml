import "../../i18n"
import QtQml
import "Search.mjs" as Search
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../"
import "../../config"

Scope {
    id: root
    property bool visible: false
    property bool independentClipboard: false
    property bool clipboardRestoring: false
    property int clipboardRestoreGeneration: 0
    property int mode: PickerService.Mode.None
    property bool privateRequest: false
    readonly property bool privateWindow: privateRequest || mode === PickerService.Mode.Secret
    property string prompt: ""
    property bool forcePrompt: false
    property bool previewImages: false
    property bool imageOnly: false
    property string secretDescription: ""
    property var secretActions: null
    property var secretCallback: null
    property var menuCallback: null
    property var menuClosedCallback: null
    property bool menuKeepOpen: false
    property bool menuKeepOpenOnCancel: false
    property string acceptLabel: Translations.text("common.actions.select")
    property string query: ""
    property string layout: "list"
    property var items: []
    property var itemCriteria: ({})
    property var selectedIds: []
    property int currentIndex: 0
    property bool multiple: false
    property bool allowTyped: false
    property bool customAccept: false
    property string requestDirectory: ""
    property string pendingDirectory: ""
    property string selectionKey: ""
    property string destination: ""
    property string destinationClass: ""
    property bool openingClipboard: false
    property string windowScope: "all"
    property bool windowSwitching: false
    property bool windowSwitchAwaitingRows: false
    property int exposeWorkspace: 0
    property int exposeReturnWorkspace: 0
    property bool exposeDragging: false
    property var exposePendingMoves: ({})
    property var exposeCloseTarget: null
    readonly property var exposeWorkspaces: {
        const native = Hyprland.workspaces.values
        const ids = [...new Set(Config.exposeWorkspaceIds.concat(native.map(ws => ws.id),
            items.map(item => item.workspaceId).filter(id => id < 0)))].filter(id => id !== 0).sort((a, b) => a - b)
        return ids.map(id => ({id, name: native.find(ws => ws.id === id)?.name || String(id)}))
    }
    property string error: ""
    property var targetScreen: null
    readonly property bool searchPending: mode === PickerService.Mode.Clipboard && clipboardSearch.pending
    readonly property bool searchFailed: mode === PickerService.Mode.Clipboard && clipboardSearch.failed
    readonly property bool searchRunning: clipboardSearch.busy
    readonly property var searchStatistics: clipboardSearch.statistics
    readonly property var filteredItems: {
        if (mode === PickerService.Mode.Clipboard) return clipboardSearch.results
        const criteria = itemCriteria
        const keys = Object.keys(criteria)
        const matching = items.filter(item => keys.every(key => item[key] === criteria[key]))
        return filter(matching, query)
    }
    readonly property var currentItem: searchPending || searchFailed ? null : filteredItems[currentIndex] ?? null
    readonly property var selectedItems: items.filter(item => selectedIds.includes(item.id))
    readonly property bool selectionToggleClears: filteredItems.length > 0
        ? filteredItems.every(item => selectedIds.includes(item.id)) : selectedIds.length > 0
    readonly property bool canAccept: !clipboardRestoring && (!!currentItem || (multiple && selectedItems.length > 0)
        || (allowTyped && query.trim().length > 0))
    signal opened()
    signal imagePreviewFailed()

    property alias clipboardFuzzy: clipboardSearch.fuzzy
    readonly property bool clipboardHasMore: clipboardSearch.hasMore
    ClipboardSearchSession {
        id: clipboardSearch
        owner: root
        onPublished: rows => root.items = rows
    }
    function queueClipboardSearch(changedRows) { clipboardSearch.refresh(changedRows) }
    function dispatchClipboardSearch() { clipboardSearch.run() }
    function loadMoreClipboard() { clipboardSearch.more() }

    function searchPattern(search) {
        return Search.searchPattern(search, Config.pickerSmartCase)
    }
    function score(text, search, pattern) {
        return Search.score(text, pattern ?? searchPattern(search), Config.pickerFuzzySearch)
    }
    function filter(rows, search) {
        const pattern = searchPattern(search)
        if (!pattern.needles.length) return rows
        return rows.map((item, index) => ({item, index,
            score: Math.min(score(String(item.title ?? ""), search, pattern),
                item.search && item.search !== item.title ? score(String(item.search), search, pattern) + 12 : Infinity)}))
            .filter(row => row.score !== Infinity)
            .sort((a, b) => a.score - b.score || a.index - b.index).map(row => row.item)
    }
    function chooseScreen() {
        return Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
    }
    function begin(newMode, title, keepVisible = false) {
        exposeCloseTarget = null
        if (pendingDirectory) {
            reply(pendingDirectory, {status: "cancelled", items: [], exitCode: 1})
            pendingDirectory = ""
        }
        close("replaced", keepVisible)
        mode = newMode; prompt = title; query = ""; items = []; selectedIds = []; currentIndex = 0
        if (newMode === PickerService.Mode.Clipboard) clipboardSearch.fuzzy = false
        itemCriteria = ({})
        let actionKey = "common.actions.select"
        switch (newMode) {
          case PickerService.Mode.Apps: actionKey = "common.actions.open"; break
          case PickerService.Mode.Windows: actionKey = "common.actions.focus"; break
        }
        acceptLabel = Translations.text(actionKey)
        layout = "list"; multiple = false; allowTyped = false; customAccept = false
        error = ""; destination = ""; destinationClass = ""; selectionKey = ""
        forcePrompt = false; previewImages = false; secretDescription = ""; privateRequest = false
        imageOnly = false
        targetScreen = chooseScreen()
    }
    function show() { visible = true; if (mode === PickerService.Mode.Clipboard) clipboardSearch.seed(); opened() }
    function promptSecret(title, description, actions, callback) {
        begin(PickerService.Mode.Secret, title)
        secretDescription = description
        secretActions = actions
        secretCallback = callback
        show()
    }
    function menuRows(rows, sorted = false) {
        const normalized = rows.map((item, index) => Object.assign({}, item, {id: String(index), result: item.result ?? item.title}))
        return sorted ? normalized.sort((a, b) => a.title.localeCompare(b.title)) : normalized
    }
    function promptMenu(title, rows, callback, presentation = "list", options = {}) {
        begin(PickerService.Mode.Menu, title, options.keepOpen === true)
        menuKeepOpen = options.keepOpen === true
        menuKeepOpenOnCancel = options.keepOpenOnCancel === true
        items = menuRows(rows, options.sort === true)
        menuCallback = callback
        menuClosedCallback = options.onClosed || null
        imageOnly = options.imageOnly === true
        previewImages = options.previewImages === true
        layout = presentation
        multiple = options.allowMultipleSelection === true
        allowTyped = options.allowTyped === true
        acceptLabel = options.acceptLabel || Translations.text("common.actions.select")
        restoreMenuSelection(options)
        show()
    }
    function restoreMenuSelection(options) {
        query = options.query || ""
        selectionKey = typeof options.selectionKey === "string" ? options.selectionKey : ""
        if (options.selectedResult === undefined && !(Config.pickerRememberSelection && selectionKey)) return
        const previous = options.selectedResult !== undefined ? options.selectedResult
            : PreferencesRepository.value("launcher.selection." + selectionKey, null)
        currentIndex = Math.max(0, filteredItems.findIndex(item =>
            JSON.stringify(item.result) === JSON.stringify(previous)))
    }
    function apps() {
        begin(PickerService.Mode.Apps, Translations.text("picker.titles.applications"))
        syncApps()
        show()
    }
    function projects(browser = false) {
        begin(PickerService.Mode.Projects, Translations.text("projects.title"))
        ProjectService.open(browser)
        show()
    }
    function directories() {
        begin(PickerService.Mode.Directories, Translations.text("directories.title"))
        allowTyped = true
        DirectoryService.open()
        show()
    }
    function n8n() {
        begin(PickerService.Mode.N8n, "n8n")
        N8nService.open()
        show()
    }
    function remotes() {
        begin(PickerService.Mode.Remotes, Translations.text("remotes.title"))
        RemoteService.open()
        show()
    }
    function webapps() {
        begin(PickerService.Mode.Webapps, Translations.text("webapps.title"))
        WebappService.open()
        show()
    }
    function syncApps() {
        const usage = PreferencesRepository.value("launcher.usage", {})
        items = DesktopEntries.applications.values.map(entry => ({id: entry.id, title: entry.name,
            search: [entry.name, entry.genericName, entry.id, ...entry.keywords].join(" "), result: entry.id}))
            .sort((a, b) => (usage[b.id] || 0) - (usage[a.id] || 0) || a.title.localeCompare(b.title))
    }
    function windowItems(scope, spatial = false) {
        const workspace = Hyprland.focusedWorkspace?.id
        let clients = WindowService.allWindows.filter(client => client.mapped !== false
            && (scope !== "current" || (client.workspace.id === workspace && !client.floating)))
        if (scope === "current" && clients.length < 2) clients = WindowService.allWindows.filter(client => client.mapped !== false)
        return clients
            .sort((a, b) => {
                if (!spatial) return (a.focusHistoryID >= 0 ? a.focusHistoryID : Infinity)
                    - (b.focusHistoryID >= 0 ? b.focusHistoryID : Infinity)
                const workspaceOrder = a.workspace.id - b.workspace.id
                if (workspaceOrder) return workspaceOrder
                if (a.grouped?.includes(b.address) || b.grouped?.includes(a.address)) {
                    return WindowService.getDisplayTitle(a.workspace.id, a.title || a.class, a.class)
                        .localeCompare(WindowService.getDisplayTitle(b.workspace.id, b.title || b.class, b.class))
                        || a.address.localeCompare(b.address)
                }
                return (a.at?.[1] ?? 0) - (b.at?.[1] ?? 0) || (a.at?.[0] ?? 0) - (b.at?.[0] ?? 0)
                    || a.address.localeCompare(b.address)
            })
            .map(client => ({id: client.address, title: client.title || client.class,
                subtitle: client.class + " · " + client.workspace.name,
                search: client.title + " " + client.class + " " + client.workspace.name, result: client.address, workspaceId: client.workspace.id, client}))
    }
    function windows(scope) {
        begin(PickerService.Mode.Windows, Translations.text(scope === "current" ? "picker.titles.workspaceWindows" : "picker.titles.windows"))
        windowScope = scope
        items = windowItems(scope)
        customAccept = true
        currentIndex = items.length > 1 ? 1 : 0
        show()
        WindowService.buildWindows()
    }
    function switchWindows() {
        if (visible && windowSwitching) { cycleWindowSwitch(1); return }
        begin(PickerService.Mode.Windows, Translations.text("picker.titles.windows"))
        windowScope = "all"
        layout = "switcher"
        windowSwitching = true
        items = windowItems("all")
        currentIndex = items.length > 1 ? 1 : 0
        windowSwitchAwaitingRows = !items.length
        show()
        Hyprland.refreshToplevels()
        WindowService.buildWindows()
    }
    function cycleWindowSwitch(delta) {
        if (!visible || !windowSwitching || !filteredItems.length) return
        currentIndex = (currentIndex + delta + filteredItems.length) % filteredItems.length
    }
    function expose(scope) {
        if (visible && layout === "expose") { close(); return }
        const focused = Hyprland.activeToplevel?.address
        begin(PickerService.Mode.Windows, Translations.text("picker.titles.windows"))
        layout = "expose"
        windowScope = "all"
        items = windowItems("all", true)
        const workspace = Hyprland.focusedWorkspace?.id ?? exposeWorkspaces[0]?.id ?? 0
        selectExposeWorkspace(scope === "all" ? 0 : workspace)
        exposeReturnWorkspace = workspace
        const focusedIndex = filteredItems.findIndex(item => item.id.replace(/^0x/, "").toLowerCase() === focused?.replace(/^0x/, "").toLowerCase())
        currentIndex = Math.max(0, focusedIndex)
        show()
        Hyprland.refreshToplevels()
        WindowService.buildWindows()
    }
    function toggleExposeAll() {
        selectExposeWorkspace(exposeWorkspace === 0 ? exposeReturnWorkspace : 0)
    }
    function selectExposeWorkspace(id) {
        if (id === 0 && exposeWorkspace !== 0) exposeReturnWorkspace = exposeWorkspace
        exposeWorkspace = id
        itemCriteria = id === 0 ? ({}) : ({workspaceId: id})
        currentIndex = 0
    }
    function activateExposeWorkspace(id) {
        exposeCloseTarget = {workspaceId: id}
        close()
    }
    function syncExpose() {
        if (!visible || layout !== "expose" || exposeDragging) return
        const nextItems = windowItems("all", true)
        // Old compositor snapshots must not restore a dropped card in its source slot.
        if (nextItems.some(item => exposePendingMoves[item.id] !== undefined
            && item.workspaceId !== exposePendingMoves[item.id])) return
        exposePendingMoves = ({})
        exposeMoveTimeout.stop()
        const id = currentItem?.id
        items = nextItems
        currentIndex = Math.max(0, filteredItems.findIndex(item => item.id === id))
    }
    function moveExposeWindow(address, workspace) {
        if (!WindowService.moveWindowToWorkspace(address, workspace)) return false
        exposePendingMoves = Object.assign({}, exposePendingMoves, {[address]: workspace})
        exposeMoveTimeout.restart()
        return true
    }
    onExposeDraggingChanged: if (!exposeDragging) syncExpose()
    Timer {
        id: exposeMoveTimeout
        interval: 1000
        onTriggered: {
            // Restore the current snapshot if the compositor did not apply the move.
            root.exposePendingMoves = ({})
            root.syncExpose()
        }
    }

    function clipboard() {
        if (independentClipboard && (visible || openingClipboard)) {
            if (visible) opened()
            return
        }
        begin(PickerService.Mode.Clipboard, Translations.text("picker.titles.clipboard"))
        if (independentClipboard) PanelFocusService.begin(root)
        openingClipboard = true
        clipboardSearch.fuzzy = false
        ClipboardService.initialize()
        syncClipboard()
        if (independentClipboard && PanelFocusService.hasTarget(root)) {
            openingClipboard = false
            destination = "panel"
            show()
            return
        }
        // Snapshot the destination before the picker takes keyboard focus.
        if (activeWindow.running) activeWindow.running = false
        openingClipboard = true
        activeWindow.running = true
    }
    function syncClipboard() {
        if (mode !== PickerService.Mode.Clipboard || (!visible && !openingClipboard)) return
        clipboardSearch.refresh()
    }
    function open(directory) {
        if (loadRequest.running) {
            reply(directory, {status: "error", items: [], exitCode: 2})
            return
        }
        begin(PickerService.Mode.Menu, "")
        pendingDirectory = directory
        loadRequest.command = Config.pickerBridgeCommand.concat(["load", directory])
        loadRequest.running = true
    }
    function reply(directory, response) {
        if (!directory) return
        const process = replyTask.createObject(root, {command: Config.pickerBridgeCommand.concat(["reply", directory]),
            input: JSON.stringify(response) + "\n"})
        process.running = true
    }
    function close(reason = "cancelled", keepVisible = false, pasteToPanel = false) {
        keepVisible = keepVisible || (reason === "cancelled" && menuKeepOpenOnCancel)
        clipboardRestoreGeneration++
        clipboardRestoring = false
        windowSwitching = false
        windowSwitchAwaitingRows = false
        const menuClosed = menuClosedCallback
        menuClosedCallback = null
        menuCallback = null
        menuKeepOpen = false
        menuKeepOpenOnCancel = false
        const secretResult = secretCallback
        secretCallback = null
        openingClipboard = false
        exposeMoveTimeout.stop()
        exposePendingMoves = ({})
        exposeDragging = false
        if (mode === PickerService.Mode.Clipboard && activeWindow.running) activeWindow.running = false
        if (requestDirectory) reply(requestDirectory, {status: "cancelled", items: [], exitCode: 1})
        requestDirectory = ""
        if (!keepVisible) visible = false
        if (imageOnly) items = []
        secretActions = null
        if (mode === PickerService.Mode.Secret) { secretDescription = ""; error = ""; prompt = "" }
        // Keep the outgoing Exposé grid stable until its closing animation ends.
        if (layout !== "expose") { query = ""; selectedIds = [] }
        if (secretResult) secretResult(null)
        if (menuClosed) menuClosed(reason)
        if (independentClipboard && !keepVisible)
            PanelFocusService.finish(root, pasteToPanel, reason !== "outside" && reason !== "replaced")
    }
    function finishExposeClose() {
        const target = exposeCloseTarget
        exposeCloseTarget = null
        // The overview surface has unmapped; compositor focus restoration can no longer override selection.
        if (target) Qt.callLater(() => {
            if (target.result) WindowService.focusWindow(target.result)
            else {
                const workspace = Hyprland.workspaces.values.find(workspace => workspace.id === target.workspaceId)
                if (workspace) workspace.activate()
                else Hyprland.dispatch("workspace " + target.workspaceId)
            }
        })
    }

    function cancel(directory) {
        if (requestDirectory === directory) close()
        if (pendingDirectory === directory) pendingDirectory = ""
    }
    function select(index, toggle) {
        currentIndex = Math.max(0, Math.min(filteredItems.length - 1, index))
        if (multiple && toggle && currentItem) {
            const id = currentItem.id
            selectedIds = selectedIds.includes(id) ? selectedIds.filter(value => value !== id) : selectedIds.concat([id])
        }
    }
    function move(delta) { select(currentIndex + delta, false) }
    function selectVisible() {
        selectedIds = [...new Set(selectedIds.concat(filteredItems.map(item => item.id)))]
    }
    function deselectAll() { selectedIds = [] }
    function toggleVisibleSelection() {
        if (selectionToggleClears) deselectAll()
        else selectVisible()
    }
    function acceptSecret(value) {
        if (mode !== PickerService.Mode.Secret || !visible) return
        if (secretCallback) {
            const callback = secretCallback
            secretCallback = null
            close()
            callback(value)
            return
        }
        if (!requestDirectory) return
        reply(requestDirectory, {status: "accepted", secret: value})
        requestDirectory = ""
        close()
    }
    function accept(custom, copyOnly) {
        if (searchPending) {
            clipboardSearch.pendingAccept = {request: clipboardSearch.request, custom, copyOnly}
            return
        }
        if (!canAccept) return
        const picked = multiple && selectedItems.length ? selectedItems
            : currentItem ? [currentItem] : [{id: "typed", title: query, result: query}]
        if (!picked.length) return
        const item = picked[0]
        switch (mode) {
          case PickerService.Mode.Menu: {
            if (Config.pickerRememberSelection && selectionKey && item.id !== "typed")
                PreferencesRepository.setValue("launcher.selection." + selectionKey, item.result)
            const callback = menuCallback
            const keepOpen = menuKeepOpen
            const state = {query}
            if (!callback && requestDirectory)
                reply(requestDirectory, {status: "accepted", items: picked, query, exitCode: custom && customAccept ? 10 : 0})
            requestDirectory = ""
            close("accepted", keepOpen)
            if (callback) callback(picked, state)
            // A synchronous next step keeps the same native surface and focus.
            // Final actions still close when their callback opens no next menu.
            if (keepOpen && !menuCallback) close()
            break
          }
          case PickerService.Mode.Projects: {
            ProjectService.accept(picked)
            break
          }
          case PickerService.Mode.Directories: {
            DirectoryService.accept(picked)
            break
          }
          case PickerService.Mode.N8n: {
            N8nService.accept(picked)
            break
          }
          case PickerService.Mode.Remotes: {
            RemoteService.accept(picked)
            return
          }
          case PickerService.Mode.Webapps: {
            WebappService.accept(picked)
            break
          }
          case PickerService.Mode.Apps: {
            const usage = Object.assign({}, PreferencesRepository.value("launcher.usage", {}))
            usage[item.id] = (usage[item.id] || 0) + 1
            PreferencesRepository.setValue("launcher.usage", usage)
            close()
            Quickshell.execDetached(["env", "-u", "ELECTRON_RUN_AS_NODE", "gtk-launch", item.result])
            break
          }
          case PickerService.Mode.Windows: {
            if (custom) WindowService.focusWindow(item.result)
            else if (layout === "expose") {
                exposeCloseTarget = item
                close()
            } else {
                close()
                // Release the layer's exclusive keyboard focus before activating the window.
                Qt.callLater(() => WindowService.focusWindow(item.result))
            }
            break
          }
          case PickerService.Mode.Clipboard: {
            if (independentClipboard && destination === "panel") {
                clipboardRestoring = true
                const generation = ++clipboardRestoreGeneration
                ClipboardService.restore(item.result, "", "", false, success => {
                    if (generation !== root.clipboardRestoreGeneration || !root.visible) return
                    root.clipboardRestoring = false
                    if (success) root.close("accepted", false, !copyOnly)
                })
                break
            }
            const target = destination; const targetClass = destinationClass
            close()
            ClipboardService.restore(item.result, target, targetClass, !copyOnly)
            break
          }
        }
    }
    onQueryChanged: { currentIndex = 0; clipboardSearch.refresh(false) }
    onItemCriteriaChanged: clipboardSearch.refresh(false)
    onFilteredItemsChanged: currentIndex = Math.max(0, Math.min(currentIndex, filteredItems.length - 1))
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { if (root.mode === PickerService.Mode.Apps) root.syncApps() }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!root.visible || Quickshell.screens.includes(root.targetScreen)) return
            root.targetScreen = root.chooseScreen()
            if (!root.targetScreen) root.close()
        }
    }
    Connections {
        target: WindowService
        function onAllWindowsChanged() {
            if (root.mode !== PickerService.Mode.Windows || !root.visible) return
            if (root.layout === "expose") { root.syncExpose(); return }
            const id = root.currentItem?.id
            const previousIndex = root.currentIndex
            const next = root.windowItems(root.windowScope)
            // Keep the cycle stable while titles, focus history and windows change.
            root.items = root.windowSwitching ? root.items.map(item => next.find(entry => entry.id === item.id)).filter(Boolean)
                .concat(next.filter(entry => !root.items.some(item => item.id === entry.id))) : next
            const index = root.filteredItems.findIndex(item => item.id === id)
            root.currentIndex = root.windowSwitchAwaitingRows ? (root.items.length > 1 ? 1 : 0)
                : index >= 0 ? index : Math.max(0, Math.min(previousIndex,root.filteredItems.length - 1))
            root.windowSwitchAwaitingRows = false
            if (root.windowSwitching && !root.items.length) root.close()
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.visible && (root.layout === "expose" || root.windowSwitching)
                && ["movewindow", "movewindowv2", "windowtitle", "windowtitlev2", "changefloatingmode", "togglegroup", "moveintogroup", "moveoutofgroup"].includes(event.name))
                WindowService.buildWindows()
        }
    }
    Process {
        id: activeWindow
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector { id: windowOutput; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (root.mode !== PickerService.Mode.Clipboard || !root.openingClipboard) return
            root.openingClipboard = false
            try {
                const client = JSON.parse(windowOutput.text)
                root.destination = client.address || ""
                root.destinationClass = client.class || ""
            } catch (_) { root.error = Translations.text("clipboard.errors.originalWindow") }
            root.show()
        }
        // qmllint enable signal-handler-parameters
    }
    Process {
        id: loadRequest
        stdout: StdioCollector { id: requestOutput; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            const directory = root.pendingDirectory
            root.pendingDirectory = ""
            if (!directory) return
            let request
            try { request = JSON.parse(requestOutput.text) } catch (_) { request = null }
            if (exitCode !== 0 || exitStatus !== 0 || !request) {
                root.reply(directory, {status: "error", items: [], exitCode: 2})
                return
            }
            // QML enum metadata can survive a reload of a running shell. Never
            // leave an invisible secret request waiting when its mode is absent.
            if (request.kind === "secret" && typeof PickerService.Mode.Secret !== "number") {
                root.reply(directory, {status: "error", items: [], exitCode: 2})
                console.warn("Secret picker unavailable; restart Quickshell.")
                return
            }
            root.privateRequest = request.private === true
            root.requestDirectory = directory
            root.prompt = request.prompt || Translations.text("common.actions.choose")
            root.forcePrompt = request.showPrompt === true
            root.previewImages = request.previewImages === true
            root.imageOnly = request.kind === "image"
            if (request.kind === "secret") {
                root.mode = PickerService.Mode.Secret
                root.secretDescription = request.description || ""
                root.error = request.errorText || ""
                root.items = []; root.query = ""; root.selectionKey = ""
                root.show()
                return
            }
            root.acceptLabel = request.acceptLabel || (Translations.text(request.action === "default" ? "bookmarks.actions.open" : "common.actions.select"))
            root.multiple = request.allowMultipleSelection === true
            root.allowTyped = request.allowTyped === true
            root.customAccept = request.customAccept === true
            root.layout = request.layout === "grid" ? "grid" : "list"
            // Source indexes are stable even when labels or provider IDs collide.
            root.items = root.menuRows(request.items, request.sort === true)
            root.restoreMenuSelection(request)
            root.show()
        }
        // qmllint enable signal-handler-parameters
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.mode === PickerService.Mode.Secret && !!root.requestDirectory
        onTriggered: if (!secretOwner.running) {
            secretOwner.directory = root.requestDirectory
            secretOwner.command = Config.pickerBridgeCommand.concat(["watch", root.requestDirectory])
            secretOwner.running = true
        }
    }
    Process {
        id: secretOwner
        property string directory: ""
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if ((exitCode !== 0 || exitStatus !== 0) && root.requestDirectory === directory
                && root.mode === PickerService.Mode.Secret) root.close()
        }
        // qmllint enable signal-handler-parameters
    }
    Component {
        id: replyTask
        Process {
            id: process
            property string input: ""
            stdinEnabled: true
            stdout: StdioCollector { waitForEnd: true }
            stderr: StdioCollector { waitForEnd: true }
            onStarted: { write(input); input = ""; stdinEnabled = false }
            // qmllint disable signal-handler-parameters
            onExited: process.destroy()
            // qmllint enable signal-handler-parameters
        }
    }
}
