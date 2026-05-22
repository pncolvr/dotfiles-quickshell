pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../config"

Singleton {
    id: root

    readonly property var windows: _internal.windows
    readonly property bool isSpecialWorkspace: _internal.isSpecialWorkspace
    property bool activeWindowHidden: _internal.activeWindowHidden
    QtObject {
        id: _internal
        property var windows: []
        property bool isSpecialWorkspace: Config.specialWorkspaces.includes(
            Hyprland.focusedWorkspace?.id ?? -1
        )
        property bool originalNoWarps: false
        property bool activeWindowHidden: false
    }

    function fetchNoWarps() {
        noWarpsProcess.running = true
    }

    function enableNoWarps() {
        // console.debug("enabling no warps")
        _setNoWarps(true)
    }

    function restoreNoWarps() {
        // console.debug("restoring no_warps:", _internal.originalNoWarps)
        _setNoWarps(_internal.originalNoWarps)
    }

    function _setNoWarps(value) {
        warpsHelperProcess.command = Config.hyprlandSetNoWarpsCommand(value)
        warpsHelperProcess.running = true
    }

    Process {
        id: warpsHelperProcess
    }

    Process {
        id: noWarpsProcess
        command: Config.hyprlandGetNoWarpsCommand
        stdout: SplitParser {
            onRead: data => {
                _internal.originalNoWarps = data.trim() === "true"
                // console.debug("WindowService: original no_warps:", _internal.originalNoWarps)
            }
        }
    }

    Process {
        id: activeWindowHiddenProcess
        command: Config.hyprlandGetActiveWindowHiddenCommand
        stdout: SplitParser {
            onRead: data => {
                // console.debug(`active window hidden: ${data}`)
                _internal.activeWindowHidden = data.trim() === "true"
            }
        }
    }

    Process {
        id: clientsProcess
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => clientsProcess._buffer += data
        }
        function getDisplayTitle(wsId, title, className) {
            // console.debug("getDisplayTitle:", wsId, title, className)
            switch (wsId) {
                case 3:
                    return Config.workspaceClassOverrides[className] ?? className
                case 4:
                    return className === "code"
                        ? title.split("-")[0].trim()
                        : title
                case 10:
                    return title
                default:
                    return cleanTitle(title)
            }
        }

        function cleanTitle(title) {
            let t = title
            for (const pat of Config.windowTitleCleanPatterns) {
                if (t.endsWith(` ${pat}`)) {
                    t = t.slice(0, -(pat.length + 1))
                }
            }
            return t.slice(0, 100)
        }

        onRunningChanged: {
            if (!running && _buffer.length > 0) {
                try {
                    const clients = JSON.parse(_buffer)
                    const wsId = Hyprland.focusedWorkspace?.id ?? -1
                    const isSpecial = Config.specialWorkspaces.includes(wsId)
                    const filtered = clients
                        .filter(c => {
                            if (c.workspace.id !== wsId) return false
                            if (isSpecial && c.floating) return false
                            if (!isSpecial && c.focusHistoryID !== 0) return false
                            return true
                        })
                        .map(c => ({
                            address: c.address,
                            title: getDisplayTitle(wsId, c.title, c.class),
                            active: c.focusHistoryID === 0,
                            className: c.class,
                            initialClass: c.initialClass,
                            initialTitle: c.initialTitle,
                            pid: c.pid,
                            floating: c.floating,
                            pinned: c.pinned,
                            fullscreen: c.fullscreen,
                            monitor: c.monitor,
                            workspace: c.workspace,
                            grouped: c.grouped,
                            tags: c.tags,
                            at: c.at,
                            size: c.size,
                            hidden: c.hidden,
                            visible: c.visible,
                            mapped: c.mapped,
                            xwayland: c.xwayland,
                            inhibitingIdle: c.inhibitingIdle,
                            stableId: c.stableId
                        }))
                        .sort((a, b) => a.title.localeCompare(b.title))
                    _internal.windows = filtered
                } catch(e) {
                    console.warn("WindowService parse error:", e)
                }
                _buffer = ""
            }
        }
    }

    function buildWindows() {
        clientsProcess.command = Config.hyprlandGetWindowsCommand
        clientsProcess._buffer = ""
        clientsProcess.running = true
        activeWindowHiddenProcess.running = true
    }

    function focusWindow(address) {
        Hyprland.dispatch(Config.hyprlandFocusWindowByAddress(address))
    }

    function cycleNext() {
        const ws = Hyprland.focusedWorkspace?.id
        if (!ws) return
        if (Config.specialWorkspaces.includes(ws)) {
            const idx = _internal.windows.findIndex(w => w.active)
            const next = _internal.windows[(idx + 1) % _internal.windows.length]
            if (next) focusWindow(next.address)
        } else {
            Hyprland.dispatch(Config.hyprlandCycleNextTiled)
        }
    }

    // Keyboard number-row mapping: 1..9 -> 0..8, 0 -> 9
    function focusIndex(index) {
        const n = parseInt(index)
        if (isNaN(n)) return
        const i = n === 0 ? 9 : n - 1
        if (i < 0 || i >= _internal.windows.length) return
        const w = _internal.windows[i]
        if (w) focusWindow(w.address)
    }

    function cyclePrev() {
        const ws = Hyprland.focusedWorkspace?.id
        if (!ws) return
        if (Config.specialWorkspaces.includes(ws)) {
            const idx = _internal.windows.findIndex(w => w.active)
            const prev = _internal.windows[(idx - 1 + _internal.windows.length) % _internal.windows.length]
            if (prev) focusWindow(prev.address)
        } else {
            Hyprland.dispatch(Config.hyprlandCyclePreviousTiled)
        }
    }

    // Connections {
    //     target: Hyprland
    //     function onRawEvent(event) {
    //         switch (event.name) {
    //             case "openwindow":
    //             case "closewindow":
    //             case "activewindowv2":
    //             case "workspacev2":
    //             case "focusedmon":
    //             case "fullscreen":
    //                 root.buildWindows()
    //                 break
    //         }
    //     }
    // }

    Connections {
        target: Hyprland.toplevels
        function onObjectInsertedPost() {
            root.buildWindows()
        }
        function onObjectRemovedPost() {
            root.buildWindows()
        }
    }

    IpcHandler {
        target: "windows"
        function next(): void { root.cycleNext() }
        function prev(): void { root.cyclePrev() }
        function focus(index: string): void { root.focusIndex(index) }
        function reload(): void { root.buildWindows() } // this can be removed if we know no_screen_share per window
    }

    Component.onCompleted: {
        fetchNoWarps();
        Hyprland.refreshToplevels()
        Qt.callLater(() => buildWindows())
    }
}