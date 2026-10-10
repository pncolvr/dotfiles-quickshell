pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../"
import "../../config"

Singleton {
    id: root
    property bool visible: false
    property string mode: ""
    property string prompt: ""
    property string acceptLabel: "Select"
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
    readonly property var filteredItems: {
        const criteria = itemCriteria
        const keys = Object.keys(criteria)
        const matching = items.filter(item => keys.every(key => item[key] === criteria[key]))
        return filter(matching, query)
    }
    readonly property var currentItem: filteredItems[currentIndex] ?? null
    readonly property var selectedItems: items.filter(item => selectedIds.includes(item.id))
    readonly property bool selectionToggleClears: filteredItems.length > 0
        ? filteredItems.every(item => selectedIds.includes(item.id)) : selectedIds.length > 0
    readonly property bool canAccept: !!currentItem || (multiple && selectedItems.length > 0)
        || (allowTyped && query.trim().length > 0)
    signal opened()

    function score(text, search) {
        if (!search.trim()) return 0
        const sensitive = Config.pickerSmartCase && search !== search.toLowerCase()
            && search !== search.toUpperCase()
        const haystack = sensitive ? text : text.toLowerCase()
        const needles = (sensitive ? search : search.toLowerCase()).trim().split(/\s+/)
        let total = 0
        for (const needle of needles) {
            if (!Config.pickerFuzzySearch) {
                const exact = haystack.indexOf(needle)
                if (exact < 0) return Infinity
                total += exact + (exact === 0 ? -20 : 0)
                continue
            }
            // Find the best subsequence, including later, more compact matches.
            // Word starts, camel-case initials and consecutive letters score better.
            let previous = []
            for (let character = 0; character < needle.length; character++) {
                const next = new Array(haystack.length).fill(Infinity)
                let bestGap = Infinity
                for (let position = 0; position < haystack.length; position++) {
                    if (character > 0 && position > 1)
                        bestGap = Math.min(bestGap, previous[position - 2] - 2 * (position - 2))
                    if (haystack[position] !== needle[character]) continue
                    const boundary = position === 0 || /[\s._:/\\-]/.test(text[position - 1])
                        || (text[position - 1] !== text[position - 1].toUpperCase()
                            && text[position] !== text[position].toLowerCase())
                    const cost = character === 0 ? Math.min(20, position * 0.1)
                        : Math.min(position > 0 ? previous[position - 1] - 16 : Infinity,
                            bestGap + 2 * (position - 1))
                    next[position] = cost - (boundary ? 12 : 0)
                }
                previous = next
            }
            const best = previous.reduce((minimum, value) => Math.min(minimum, value), Infinity)
            if (best === Infinity) return Infinity
            total += best
        }
        return total
    }
    function filter(rows, search) {
        return rows.map((item, index) => ({item: item, index: index,
            score: Math.min(score(String(item.title ?? ""), search),
                item.search ? score(String(item.search), search) + 12 : Infinity)}))
            .filter(row => row.score !== Infinity)
            .sort((a, b) => a.score - b.score || a.index - b.index).map(row => row.item)
    }
    function chooseScreen() {
        return Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
    }
    function begin(newMode, title) {
        exposeCloseTarget = null
        if (pendingDirectory) {
            reply(pendingDirectory, {status: "cancelled", items: [], exitCode: 1})
            pendingDirectory = ""
        }
        close()
        mode = newMode; prompt = title; query = ""; items = []; selectedIds = []; currentIndex = 0
        itemCriteria = ({})
        acceptLabel = newMode === "apps" ? "Open" : newMode === "windows" ? "Focus" : "Select"
        layout = "list"; multiple = false; allowTyped = false; customAccept = false
        error = ""; destination = ""; destinationClass = ""; selectionKey = ""
        targetScreen = chooseScreen()
    }
    function show() { visible = true; opened() }
    function apps() {
        begin("apps", "Applications")
        syncApps()
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
                if (!spatial) return a.focusHistoryID - b.focusHistoryID
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
        begin("windows", scope === "current" ? "Windows in this workspace" : "Windows")
        windowScope = scope
        items = windowItems(scope)
        customAccept = true
        currentIndex = items.length > 1 ? 1 : 0
        if (items.length === 2) {
            const previous = items[1]
            WindowService.focusWindow(previous.result)
            return
        }
        show()
        WindowService.buildWindows()
    }
    function expose(scope) {
        if (visible && layout === "expose") { close(); return }
        const focused = Hyprland.activeToplevel?.address
        begin("windows", "Windows")
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
        begin("clipboard", "Clipboard")
        ClipboardService.initialize()
        syncClipboard()
        // Snapshot the destination before the picker takes keyboard focus.
        if (activeWindow.running) activeWindow.running = false
        openingClipboard = true
        activeWindow.running = true
    }
    function syncClipboard() {
        if (mode !== "clipboard") return
        items = ClipboardRepository.entries().map(entry => ({id: entry.id,
            pinned: !!entry.pinned,
            title: entry.kind === "image" ? "" : entry.text.replace(/\s+/g, " ").slice(0, 240),
            search: entry.kind === "image" ? entry.mime + " image" : entry.text,
            image: entry.kind === "image" ? "file://" + Config.clipboardDirectory + "/" + entry.id : "",
            result: entry}))
    }
    function open(directory) {
        if (loadRequest.running) {
            reply(directory, {status: "error", items: [], exitCode: 2})
            return
        }
        begin("menu", "")
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
    function close() {
        openingClipboard = false
        exposeMoveTimeout.stop()
        exposePendingMoves = ({})
        exposeDragging = false
        if (mode === "clipboard" && activeWindow.running) activeWindow.running = false
        if (requestDirectory) reply(requestDirectory, {status: "cancelled", items: [], exitCode: 1})
        requestDirectory = ""
        visible = false
        // Keep the outgoing Exposé grid stable until its closing animation ends.
        if (layout !== "expose") { query = ""; selectedIds = [] }
    }
    function finishExposeClose() {
        const target = exposeCloseTarget
        exposeCloseTarget = null
        // The overview surface has unmapped; compositor focus restoration can no longer override selection.
        if (target) Qt.callLater(() => WindowService.focusWindow(target.result))
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
    function accept(custom, copyOnly) {
        if (!canAccept) return
        const picked = multiple && selectedItems.length ? selectedItems
            : currentItem ? [currentItem] : [{id: "typed", title: query, result: query}]
        if (!picked.length) return
        const item = picked[0]
        if (mode === "menu") {
            if (Config.pickerRememberSelection && selectionKey && item.id !== "typed")
                PreferencesRepository.setValue("launcher.selection." + selectionKey, item.result)
            reply(requestDirectory, {status: "accepted", items: picked, exitCode: custom && customAccept ? 10 : 0})
            requestDirectory = ""
            close()
        } else if (mode === "apps") {
            const usage = Object.assign({}, PreferencesRepository.value("launcher.usage", {}))
            usage[item.id] = (usage[item.id] || 0) + 1
            PreferencesRepository.setValue("launcher.usage", usage)
            close()
            Quickshell.execDetached(["gtk-launch", item.result])
        } else if (mode === "windows") {
            if (custom) WindowService.focusWindow(item.result)
            else if (layout === "expose") {
                exposeCloseTarget = item
                close()
            } else {
                close()
                // Release the layer's exclusive keyboard focus before activating the window.
                Qt.callLater(() => WindowService.focusWindow(item.result))
            }
        } else if (mode === "clipboard") {
            const target = destination; const targetClass = destinationClass
            close()
            ClipboardService.restore(item.result, target, targetClass, !copyOnly)
        }
    }
    onQueryChanged: currentIndex = 0
    onFilteredItemsChanged: currentIndex = Math.max(0, Math.min(currentIndex, filteredItems.length - 1))
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { if (root.mode === "apps") root.syncApps() }
    }
    Connections {
        target: ClipboardRepository
        function onRevisionChanged() { root.syncClipboard() }
    }
    Connections {
        target: WindowService
        function onAllWindowsChanged() {
            if (root.mode !== "windows" || !root.visible) return
            if (root.layout === "expose") { root.syncExpose(); return }
            const id = root.currentItem?.id
            root.items = root.windowItems(root.windowScope)
            root.currentIndex = Math.max(0, root.filteredItems.findIndex(item => item.id === id))
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.visible && root.layout === "expose"
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
            if (root.mode !== "clipboard" || !root.openingClipboard) return
            root.openingClipboard = false
            try {
                const client = JSON.parse(windowOutput.text)
                root.destination = client.address || ""
                root.destinationClass = client.class || ""
            } catch (_) { root.error = "Original window unavailable. Use Copy, then paste manually." }
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
            root.requestDirectory = directory
            root.prompt = request.prompt || "Choose"
            root.acceptLabel = request.acceptLabel || (request.action === "default" ? "Open links" : "Select")
            root.multiple = request.allowMultipleSelection === true
            root.allowTyped = request.allowTyped === true
            root.customAccept = request.customAccept === true
            root.layout = request.layout === "grid" ? "grid" : "list"
            // Source indexes are stable even when labels or provider IDs collide.
            const rows = request.items.map((item, index) => Object.assign({}, item, {id: String(index), result: item.result ?? item.title}))
            root.items = request.sort === true ? rows.sort((a, b) => a.title.localeCompare(b.title)) : rows
            root.query = request.query || ""
            root.selectionKey = typeof request.selectionKey === "string" ? request.selectionKey : ""
            if (Config.pickerRememberSelection && root.selectionKey) {
                const previous = PreferencesRepository.value("launcher.selection." + root.selectionKey, null)
                root.currentIndex = Math.max(0, root.filteredItems.findIndex(item =>
                    JSON.stringify(item.result) === JSON.stringify(previous)))
            }
            root.show()
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
            onStarted: { write(input); stdinEnabled = false }
            // qmllint disable signal-handler-parameters
            onExited: process.destroy()
            // qmllint enable signal-handler-parameters
        }
    }
    IpcHandler {
        target: "launcher"
        function apps(): void { root.apps() }
        function windows(scope: string): void { root.windows(scope) }
        function expose(scope: string): void { root.expose(scope) }
        function clipboard(): void { root.clipboard() }
        function open(directory: string): void { root.open(directory) }
        function cancel(directory: string): void { root.cancel(directory) }
        function alive(): bool { return true }
    }
}
