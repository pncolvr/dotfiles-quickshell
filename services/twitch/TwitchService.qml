pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root

    readonly property var onlineUsers: _internal.onlineUsers
    readonly property var offlineUsers: _internal.offlineUsers
    readonly property var allUsers: _internal.combinedUsers
    readonly property bool hasOnline: _internal.hasOnline
    
    readonly property bool available: _internal.available
    
    QtObject {
        id: _internal 
        property string cacheDir: Config.twitchCacheDir
        property var allUsers: []
        property var downloadQueue: []

        property var onlineUsers: []
        property var offlineUsers: []
        property bool hasOnline: onlineUsers.length > 0
        property bool available: false

        property var combinedUsers: {
            var combined = [...onlineUsers, ...offlineUsers]
            return combined.sort((a, b) => a.login.localeCompare(b.login))
        }
    }

    Process {
        id: checkProcess
        command: ["bash", "-c", `which ${Config.twitchCli} > /dev/null 2>&1 && echo "1" || echo "0"`]
        running: true
        stdout: SplitParser {
            onRead: data => _internal.available = data.trim() === "1"
        }
    }

    function openUrl(login) {
        Qt.openUrlExternally(`${Config.twitchBaseUrl}${login}`)
    }

    function openStream(login) {
        helperProcess.command = ["bash", "-c", `${Config.twitchStreamCommand.join(" ")} "${login}" "${Config.twitchBaseUrl}${login}" &`]
        helperProcess.running = true
    }

    function openPicker() {
        helperProcess.command = ["bash", "-c", `${Config.twitchStreamCommand.join(" ")} &`]
        helperProcess.running = true
    }

    Process {
        id: helperProcess
    }

    function refresh() {
        if (!available) return
        usersFile.reload()
    }

    function avatarPath(login) {
        return `${_internal.cacheDir}/${login}.jpg`
    }

    function fetchAvatars(users) {
        const query = users.map(u => `login=${u}`).join("&")
        avatarQueryProcess.command = ["bash", "-c",
            `${Config.twitchCli} api get "users?${query}"`
        ]
        avatarQueryProcess._buffer = ""
        avatarQueryProcess.running = true
    }

    function ensureCacheDir() {
        cacheDirProcess.running = true
    }

    function _processQueue() {
        if (_internal.downloadQueue.length === 0) return
        const next = _internal.downloadQueue.shift()
        downloadProcess.command = ["bash", "-c",
            `[ -f "${next.path}" ] || curl -s -o "${next.path}" "${next.url}"`
        ]
        downloadProcess.running = true
    }

    FileView {
        id: usersFile
        path: Config.twitchUsersFile
        onLoaded: {
            const users = usersFile.text().trim().split("\n").filter(u => u.length > 0)
            _internal.allUsers = users
            _internal.offlineUsers = users.map(u => ({ login: u, online: false, avatar: root.avatarPath(u) }))
            const query = users.map(u => `user_login=${u}`).join("&")
            streamsProcess.command = ["bash", "-c",
                `${Config.twitchCli} api get "streams?${query}"`
            ]
            streamsProcess._buffer = ""
            streamsProcess.running = NetworkService.online
        }
    }

    Process {
        id: cacheDirProcess
        command: ["mkdir", "-p", _internal.cacheDir]
    }

    Process {
        id: streamsProcess
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => streamsProcess._buffer += data
        }
        stderr: SplitParser {
            onRead: data => console.warn("TwitchService streams error:", data)
        }
        onRunningChanged: {
            if (!running && _buffer.length > 0) {
                try {
                    const json = JSON.parse(_buffer)
                    const previousOnline = _internal.onlineUsers.map(u => u.login)
                    
                    const onlineLogins = json.data.map(s => ({
                        login: s.user_login,
                        online: true,
                        viewers: s.viewer_count,
                        title: s.title,
                        game: s.game_name,
                        avatar: root.avatarPath(s.user_login)
                    }))
                    const onlineNames = onlineLogins.map(u => u.login)
                    const newOnline = onlineNames.filter(u => !previousOnline.includes(u))

                    _internal.onlineUsers = onlineLogins.sort((a, b) => a.login.localeCompare(b.login))
                    _internal.offlineUsers = _internal.allUsers
                        .filter(u => !onlineNames.includes(u))
                        .sort()
                        .map(u => ({ login: u, online: false, avatar: root.avatarPath(u) }))

                    if (newOnline.length > 0) {
                        notifyProcess.command = ["notify-send", "--transient", "Twitch", newOnline.join(", ") + " went live"]
                        notifyProcess.running = true
                    }

                    const items = onlineNames.map(login => ({
                        title: ` ${login}`,
                        result: `https://www.twitch.tv/${login}`
                    }))

                    const outJson = JSON.stringify({
                        prompt: "",
                        action: "output",
                        allowTyped: false,
                        allowMultipleSelection: false,
                        sort: false,
                        items: items
                    })

                    writeProcess.command = ["bash", "-c", `echo '${outJson}' > ${Config.twitchOnlineFile}`]
                    writeProcess.running = true

                    root.ensureCacheDir()
                    root.fetchAvatars(_internal.allUsers)
                } catch(e) {
                    console.warn("TwitchService parse error:", e)
                }
                _buffer = ""
            }
        }
    }

    Process {
        id: notifyProcess
    }

    Process {
        id: writeProcess
    }

    Process {
        id: avatarQueryProcess
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => avatarQueryProcess._buffer += data
        }
        stderr: SplitParser {
            onRead: data => console.warn("TwitchService avatar error:", data)
        }
        onRunningChanged: {
            if (!running && _buffer.length > 0) {
                try {
                    const json = JSON.parse(_buffer)
                    json.data.forEach(user => {
                        _internal.downloadQueue.push({
                            path: root.avatarPath(user.login),
                            url: user.profile_image_url
                        })
                    })
                    root._processQueue()
                } catch(e) {
                    console.warn("TwitchService avatar parse error:", e)
                }
                _buffer = ""
            }
        }
    }

    Process {
        id: downloadProcess
        stderr: SplitParser {
            onRead: data => console.warn("TwitchService download error:", data)
        }
        onRunningChanged: if (!running) root._processQueue()
    }

    Connections {
        target: NetworkService
        function onOnlineChanged() {
            if (NetworkService.online) root.refresh()
        }
    }

    Timer {
        interval: Config.twitchInterval
        running: _internal.available
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        if (NetworkService.online) refresh()
    }
}