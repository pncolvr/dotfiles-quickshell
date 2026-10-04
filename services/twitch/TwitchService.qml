pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root

    readonly property var onlineUsers: state.onlineUsers
    readonly property var offlineUsers: {
        TimeService.time // Reformat relative dates when the clock changes, including midnight.
        return formatOfflineUsers(state.offlineUsers, Date.now())
    }
    readonly property var allUsers: [...onlineUsers, ...offlineUsers].sort((a, b) => a.login.localeCompare(b.login))
    readonly property bool hasOnline: onlineUsers.length > 0
    readonly property bool available: state.available
    readonly property bool usersReady: DbService.ready
    readonly property string error: TwitchRepository.error

    onUsersReadyChanged: if (usersReady) Qt.callLater(root.refresh)

    QtObject {
        id: state
        property var onlineUsers: []
        property var offlineUsers: []
        property var downloadQueue: []
        property var userIds: ({})
        property var scheduleQueue: []
        property bool available: false
        property bool refreshing: false
        property bool refreshAgain: false
        readonly property int scheduleCacheDuration: 60 * 60 * 1000
    }

    function openUrl(login) { Qt.openUrlExternally(`${Config.twitchBaseUrl}${login}`) }
    function openStream(login) {
        Quickshell.execDetached(Config.twitchStreamCommand(login, `${Config.twitchBaseUrl}${login}`))
    }
    function openPicker() { Quickshell.execDetached(Config.twitchStreamCommand()) }
    function notifyOnline(logins) {
        if (!logins.length || notifyProcess.running) return
        notifyProcess.command = ["notify-send", "--app-name=Twitch", "--urgency=low",
            "--action=default=Open Twitch", "--action=open-twitch=Open Twitch", "--icon",
            Qt.resolvedUrl("../../assets/twitch.png").toString().replace("file://", ""), logins.join("\n")]
        notifyProcess.running = true
    }
    function avatarSource(login) { return TwitchRepository.avatars[login]?.dataUrl ?? "" }
    function addUser(login) { return usersReady && TwitchRepository.addUser(login) }
    function removeUser(login) { return usersReady && TwitchRepository.removeUser(login) }

    function syncUsers() {
        const logins = TwitchRepository.logins()
        state.onlineUsers = state.onlineUsers.filter(user => logins.includes(user.login))
        const online = state.onlineUsers.map(user => user.login)
        state.offlineUsers = logins.filter(login => !online.includes(login)).map(login => ({
            login, online: false, avatar: avatarSource(login),
            nextStreamAt: TwitchRepository.schedules[login]?.startsAt ?? null
        }))
    }

    function formatOfflineUsers(users, now) {
        return users.map(user => Object.assign({}, user, {
            nextStream: user.nextStreamAt > now ? CalendarService.formatDate(user.nextStreamAt, now) : ""
        }))
    }

    function reload() {
        if (TwitchRepository.reload()) refresh()
    }

    function refresh() {
        if (!available || !usersReady || !NetworkService.online) return
        if (state.refreshing) {
            state.refreshAgain = true
            return
        }
        state.refreshAgain = false
        const logins = TwitchRepository.logins()
        if (!logins.length) {
            syncUsers()
            writeOnlineExport()
            return
        }
        state.refreshing = true
        const query = logins.map(login => `user_login=${encodeURIComponent(login)}`).join("&")
        streamsProcess.command = [Config.twitchCli, "api", "get", `streams?${query}`]
        streamsProcess.running = true
    }

    function finishRefresh() {
        state.refreshing = false
        if (state.refreshAgain) Qt.callLater(root.refresh)
    }

    function writeOnlineExport() {
        onlineFile.setText(JSON.stringify({
            prompt: "", action: "output", allowTyped: false, allowMultipleSelection: false, sort: false,
            items: state.onlineUsers.map(user => ({title: ` ${user.login}`, result: `${Config.twitchBaseUrl}${user.login}`}))
        }))
    }

    function fetchAvatars() {
        const logins = TwitchRepository.logins()
        if (!logins.length) { finishRefresh(); return }
        const query = logins.map(login => `login=${encodeURIComponent(login)}`).join("&")
        avatarQueryProcess.command = [Config.twitchCli, "api", "get", `users?${query}`]
        avatarQueryProcess.running = true
    }

    function processDownloadQueue() {
        if (downloadProcess.running || !state.downloadQueue.length) return
        state.downloadQueue = state.downloadQueue.filter(item => TwitchRepository.logins().includes(item.login))
        if (!state.downloadQueue.length) return
        const next = state.downloadQueue.shift()
        downloadProcess.login = next.login
        downloadProcess.sourceUrl = next.url
        downloadProcess.command = ["bash", "-o", "pipefail", "-c",
            'curl -fsSL --max-time 15 --max-filesize 1048576 "$1" | base64 -w0', "twitch-avatar", next.url]
        downloadProcess.running = true
    }

    function scheduleIsFresh(cache, now) {
        return !!cache && now >= cache.fetchedAt && now - cache.fetchedAt < state.scheduleCacheDuration
            && (cache.startsAt === null || cache.startsAt > now)
    }

    function fetchSchedules() {
        const now = Date.now()
        state.scheduleQueue = state.offlineUsers.map(user => user.login).filter(login =>
            state.userIds[login] && !scheduleIsFresh(TwitchRepository.schedules[login], now))
        processScheduleQueue()
    }

    function nextScheduledStream(segments, now) {
        const dates = segments.filter(segment => segment && !segment.canceled_until)
            .map(segment => Date.parse(segment.start_time)).filter(date => Number.isFinite(date) && date > now)
        return dates.length ? Math.min(...dates) : null
    }

    function processScheduleQueue() {
        if (scheduleProcess.running) return
        const logins = TwitchRepository.logins()
        state.scheduleQueue = state.scheduleQueue.filter(login => logins.includes(login))
        if (!state.scheduleQueue.length) { finishRefresh(); return }
        const login = state.scheduleQueue.shift()
        scheduleProcess.login = login
        scheduleProcess.command = [Config.twitchCli, "api", "get", `schedule?broadcaster_id=${encodeURIComponent(state.userIds[login])}&first=5`]
        scheduleProcess.running = true
    }

    FileView {
        id: onlineFile
        path: Config.twitchOnlineFile
        preload: false
        printErrors: false
    }

    Process {
        command: ["which", Config.twitchCli]
        running: true
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => { state.available = exitCode === 0 && exitStatus === 0 }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: streamsProcess
        stdout: StdioCollector { id: streamsOutput; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) { root.finishRefresh(); return }
            try {
                const json = JSON.parse(streamsOutput.text)
                if (!Array.isArray(json.data)) throw new Error("Missing streams data")
                const previousOnline = state.onlineUsers.map(user => user.login)
                const logins = TwitchRepository.logins()
                state.onlineUsers = json.data.filter(stream => logins.includes(stream.user_login.toLowerCase())).map(stream => ({
                    login: stream.user_login.toLowerCase(), online: true, viewers: stream.viewer_count,
                    title: stream.title, game: stream.game_name, avatar: root.avatarSource(stream.user_login.toLowerCase())
                })).sort((a, b) => a.login.localeCompare(b.login))
                root.syncUsers()
                const newlyOnline = state.onlineUsers.map(user => user.login).filter(login => !previousOnline.includes(login))
                root.notifyOnline(newlyOnline)
                root.writeOnlineExport()
                root.fetchAvatars()
            } catch (error) {
                console.warn("TwitchService streams response:", error)
                root.finishRefresh()
            }
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: notifyProcess
        stdout: StdioCollector { id: notifyOutput; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) return
            const action = notifyOutput.text.trim()
            if (action === "default" || action === "open-twitch") Qt.openUrlExternally(Config.twitchBaseUrl)
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: avatarQueryProcess
        stdout: StdioCollector { id: avatarOutput; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0) {
                try {
                    const json = JSON.parse(avatarOutput.text)
                    if (!Array.isArray(json.data)) throw new Error("Missing users data")
                    const logins = TwitchRepository.logins()
                    for (const user of json.data) {
                        const login = user.login.toLowerCase()
                        if (!logins.includes(login)) continue
                        state.userIds[login] = user.id
                        const url = user.profile_image_url
                        const cached = TwitchRepository.avatars[login]
                        if (url && cached?.sourceUrl !== url && !state.downloadQueue.some(item => item.login === login)
                            && !(downloadProcess.running && downloadProcess.login === login && downloadProcess.sourceUrl === url))
                            state.downloadQueue.push({login, url})
                    }
                    root.processDownloadQueue()
                } catch (error) { console.warn("TwitchService users response:", error) }
            }
            root.fetchSchedules()
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: downloadProcess
        objectName: "twitchAvatarDownload"
        property string login: ""
        property string sourceUrl: ""
        stdout: StdioCollector { id: downloadOutput; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0)
                TwitchRepository.saveAvatar(login, sourceUrl, downloadOutput.text.trim(), Date.now())
            root.processDownloadQueue()
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: scheduleProcess
        property string login: ""
        stdout: StdioCollector { id: scheduleOutput; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitStatus === 0 && scheduleOutput.text) {
                try {
                    const json = JSON.parse(scheduleOutput.text)
                    const now = Date.now()
                    if (exitCode === 0 && Array.isArray(json.data?.segments))
                        TwitchRepository.saveSchedule(login, root.nextScheduledStream(json.data.segments, now), now)
                    else if (json.status === 404)
                        TwitchRepository.saveSchedule(login, null, now)
                } catch (error) { console.warn("TwitchService schedule response:", error) }
            }
            root.processScheduleQueue()
        }
        // qmllint enable signal-handler-parameters
    }

    Connections {
        target: TwitchRepository
        function onUsersChanged() {
            root.syncUsers()
            root.writeOnlineExport()
            root.refresh()
        }
        function onSchedulesChanged() { root.syncUsers() }
        function onAvatarsChanged() {
            state.onlineUsers = state.onlineUsers.map(user => Object.assign({}, user, {avatar: root.avatarSource(user.login)}))
            root.syncUsers()
        }
    }

    Connections {
        target: NetworkService
        function onOnlineChanged() { if (NetworkService.online) root.refresh() }
    }

    Timer {
        interval: Config.twitchInterval
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: syncUsers()

    IpcHandler {
        target: "twitch"
        function reload(): void { root.reload() }
        function addUser(login: string): bool { return root.addUser(login) }
        function removeUser(login: string): bool { return root.removeUser(login) }
        function exportUsers(): string { return TwitchRepository.exportUsers() }
    }
}
