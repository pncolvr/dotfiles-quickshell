pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root

    readonly property var updates: _internal.updates
    readonly property var priorityUpdates: _internal.priorityUpdates
    readonly property var normalUpdates: _internal.normalUpdates
    readonly property int count: _internal.count
    readonly property bool hasUpdates: _internal.hasUpdates
    readonly property bool hasPriority: _internal.hasPriority

    QtObject {
        id: _internal
        property var updates: []
        property var priorityUpdates: []
        property var normalUpdates: []
        property int count: updates.length
        property bool hasUpdates: count > 0
        property bool hasPriority: priorityUpdates.length > 0
    }

    function install() {
        installProcess.command = Config.updatesInstallCommand
        installProcess.running = true
    }

    Process {
        id: installProcess
    }

    function refresh() {
        _internal.updates = []
        _internal.priorityUpdates = []
        _internal.normalUpdates = []
        updatesProcess.running = true
    }

    function isPriority(line) {
        return Config.updatesPriorityPatterns.some(p => new RegExp(p).test(line))
    }

    Process {
        id: updatesProcess
        command: Config.updatesCheckCommand
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (!line) return
                const parts = line.split(/\s+/)
                const update = {
                    name: parts[0],
                    oldVersion: parts[1],
                    newVersion: parts[3]
                }
                if (root.isPriority(line)) {
                    _internal.priorityUpdates = [..._internal.priorityUpdates, update]
                } else {
                    _internal.normalUpdates = [..._internal.normalUpdates, update]
                }
                _internal.updates = [..._internal.priorityUpdates, ...root.normalUpdates]
            }
        }
    }
    Connections {
        target: NetworkService
        function onOnlineChanged() {
            if (NetworkService.online) root.refresh()
        }
    }

    Timer {
        interval: Config.updatesInterval
        running: true && NetworkService.online
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        if (NetworkService.online) refresh()
    }
}