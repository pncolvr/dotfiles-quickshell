pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../../config"
import "../"

Singleton {
    id: root

    readonly property var entries: selectUsers(TwitchRepository.users, state.streams)
    readonly property var onlineUsers: entries.filter(user => user.online)
    readonly property var offlineUsers: {
        TimeService.time // Reformat relative dates when the clock changes, including midnight.
        return formatOfflineUsers(entries.filter(user => !user.online), Date.now())
    }
    readonly property var allUsers: [...onlineUsers, ...offlineUsers].sort((a, b) => a.login.localeCompare(b.login))
    readonly property bool hasOnline: onlineUsers.length > 0
    readonly property bool available: state.available
    readonly property bool usersReady: DbService.ready
    readonly property string error: TwitchRepository.error
    readonly property var removedUsers: TwitchRepository.removedUsers.map(entry => ({login: entry.user.login, expiresAt: entry.expiresAt}))
    readonly property var browserSuggestions: {
        const followed = TwitchRepository.channelLogins()
        return state.browserLogins.filter(login => !followed.includes(login))
    }
    onUsersReadyChanged: if (usersReady) Qt.callLater(root.refresh)
    onAvailableChanged: if (available) Qt.callLater(root.refresh)

    QtObject {
        id: state
        property var streams: []
        property var downloadQueue: []
        property var userIds: ({})
        property var scheduleQueue: []
        property var browserLogins: []
        property var notificationQueue: []
        property var streamQueue: []
        property var pendingStreams: []
        property var avatarQueue: []
        property bool available: false
        property bool refreshing: false
        property bool refreshAgain: false
        readonly property int scheduleCacheDuration: 60 * 60 * 1000
    }

    function openUrl(login) { Qt.openUrlExternally(`${Config.twitchBaseUrl}${login}`) }
    function streamNotification(changes) {
        const sections = []
        let summary = ""
        for (const [heading, streams] of [["Live", changes.online], ["Offline", changes.offline]]) {
            if (!streams.length) continue
            const title = summary ? `**${heading}**\n\n` : ""
            if (!summary) summary = heading
            sections.push(title + streams.map(stream => `\`${stream.login}\``).join("  \n"))
        }
        return {summary, body: sections.join("\n\n")}
    }

    function notifyChanges(changes) {
        if (!changes.online.length && !changes.offline.length) return
        state.notificationQueue.push(streamNotification(changes))
        processNotificationQueue()
    }

    function processNotificationQueue() {
        if (notifyProcess.running || !state.notificationQueue.length) return
        const notification = state.notificationQueue.shift()
        notifyProcess.command = ["notify-send", "--app-name=Twitch", "--urgency=normal",
            "--icon",
            Qt.resolvedUrl("../../assets/twitch.png").toString().replace("file://", ""), "--", notification.summary, notification.body]
        notifyProcess.running = true
    }
    function avatarSource(login) { return TwitchRepository.avatars[login]?.dataUrl ?? "" }
    function addUser(login, fallback = "", linkExisting = false) { return usersReady && TwitchRepository.addUser(login, fallback, linkExisting) }
    function updateUser(original, login, fallback = "", linkExisting = false) {
        return usersReady && TwitchRepository.updateUser(original, login, fallback, linkExisting)
    }
    function fallbackEntry(login, original = "") { return TwitchRepository.fallbackEntry(login, original) }
    function removeUser(login) { return usersReady && TwitchRepository.removeUser(login) }
    function undoRemoveUser(login) { return usersReady && TwitchRepository.undoRemoveUser(login) }
    function undoAllRemovals() {
        const logins = removedUsers.map(entry => entry.login)
        if (!logins.length) return false
        for (const login of logins) {
            if (!undoRemoveUser(login)) return false
        }
        return true
    }

    function refreshBrowserSuggestions() {
        if (!browserSessionProcess.running) browserSessionProcess.running = true
    }

    function selectUsers(users, streams) {
        const live = Object.create(null)
        for (const stream of streams) live[stream.login] = stream
        return users.map(user => {
            const stream = live[user.login] ?? live[user.fallbackLogin]
            const login = stream?.login ?? user.login
            return Object.assign({}, stream ?? {}, {login, mainLogin: user.login,
                fallbackLogin: user.fallbackLogin ?? "", usingFallback: !!stream && login !== user.login,
                online: !!stream, avatar: avatarSource(login),
                nextStreamAt: TwitchRepository.schedules[user.login]?.startsAt ?? null})
        }).sort((a, b) => a.login.localeCompare(b.login))
    }

    function syncUsers() {
        const logins = TwitchRepository.channelLogins()
        state.streams = state.streams.filter(user => logins.includes(user.login))
    }

    function formatOfflineUsers(users, now) {
        return users.map(user => Object.assign({}, user, {
            nextStream: user.nextStreamAt > now ? CalendarService.formatDate(user.nextStreamAt, now) : ""
        }))
    }

    function reload() {
        if (TwitchRepository.reload()) refresh()
    }

    function isRefreshMinute(now, interval = Config.twitchInterval) {
        const minutes = Math.max(1, interval / Timespan.fromMinutes(1))
        return new Date(now).getMinutes() % minutes === 0
    }

    function refresh() {
        if (!available || !usersReady || !NetworkService.online) return
        if (state.refreshing) {
            state.refreshAgain = true
            return
        }
        state.refreshAgain = false
        const logins = TwitchRepository.channelLogins()
        if (!logins.length) {
            syncUsers()
            return
        }
        state.refreshing = true
        state.streamQueue = queryBatches(logins)
        state.pendingStreams = []
        fetchStreams()
    }

    function queryBatches(logins) {
        const batches = []
        // Helix accepts at most 100 channel logins per request.
        for (let index = 0; index < logins.length; index += 100) batches.push(logins.slice(index, index + 100))
        return batches
    }

    function fetchStreams() {
        const logins = state.streamQueue.shift()
        const query = logins.map(login => `user_login=${encodeURIComponent(login)}`).join("&")
        streamsProcess.command = [Config.twitchCli, "api", "get", `streams?first=100&${query}`]
        streamsProcess.running = true
    }

    function finishRefresh() {
        state.refreshing = false
        if (state.refreshAgain) Qt.callLater(root.refresh)
    }

    function fetchAvatars() {
        const logins = TwitchRepository.channelLogins()
        if (!logins.length) { finishRefresh(); return }
        state.avatarQueue = queryBatches(logins)
        fetchAvatarBatch()
    }

    function fetchAvatarBatch() {
        const logins = state.avatarQueue.shift()
        const query = logins.map(login => `login=${encodeURIComponent(login)}`).join("&")
        avatarQueryProcess.command = [Config.twitchCli, "api", "get", `users?${query}`]
        avatarQueryProcess.running = true
    }

    function processDownloadQueue() {
        if (downloadProcess.running || !state.downloadQueue.length) return
        state.downloadQueue = state.downloadQueue.filter(item => TwitchRepository.channelLogins().includes(item.login))
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
        const online = state.streams.map(user => user.login)
        state.scheduleQueue = TwitchRepository.logins().filter(login => !online.includes(login)).filter(login =>
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

    Process {
        id: browserSessionProcess
        command: ["bash", Qt.resolvedUrl("qutebrowser-channels.sh").toString().replace("file://", ""), ...Config.qutebrowserSessionFiles]
        stdout: StdioCollector { id: browserSessionOutput; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            state.browserLogins = []
            if (exitCode !== 0 || exitStatus !== 0) return
            try {
                const logins = JSON.parse(browserSessionOutput.text)
                if (Array.isArray(logins))
                    state.browserLogins = [...new Set(logins.filter(login => typeof login === "string" && TwitchRepository.validLogin(login)))].sort()
            } catch (error) { console.warn("TwitchService browser session response:", error) }
        }
        // qmllint enable signal-handler-parameters
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
        objectName: "twitchStreamsQuery"
        stdout: StdioCollector { id: streamsOutput; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitStatus !== 0) { root.finishRefresh(); return }
            try {
                // The CLI update check can fail after a successful API response; validate the JSON itself.
                const json = JSON.parse(streamsOutput.text)
                if (!Array.isArray(json.data)) throw new Error("Missing streams data")
                const logins = TwitchRepository.channelLogins()
                state.pendingStreams = [...state.pendingStreams, ...json.data.filter(stream => logins.includes(stream.user_login.toLowerCase())).map(stream => ({
                    login: stream.user_login.toLowerCase(), streamId: String(stream.id ?? stream.started_at ?? ""),
                    online: true, viewers: stream.viewer_count,
                    title: stream.title, game: stream.game_name, avatar: root.avatarSource(stream.user_login.toLowerCase())
                }))]
                if (state.streamQueue.length) { Qt.callLater(root.fetchStreams); return }
                state.streams = state.pendingStreams.filter(stream => logins.includes(stream.login))
                const changes = TwitchRepository.updateStreamSnapshot(state.streams)
                if (changes) root.notifyChanges(changes)
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
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: Qt.callLater(root.processNotificationQueue)
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: avatarQueryProcess
        stdout: StdioCollector { id: avatarOutput; waitForEnd: true }
        // Quickshell.Io omits QProcess::ExitStatus from its qmltypes.
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitStatus === 0) {
                try {
                    const json = JSON.parse(avatarOutput.text)
                    if (!Array.isArray(json.data)) throw new Error("Missing users data")
                    const logins = TwitchRepository.channelLogins()
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
            if (state.avatarQueue.length) Qt.callLater(root.fetchAvatarBatch)
            else root.fetchSchedules()
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
                    if (Array.isArray(json.data?.segments))
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
            root.refresh()
        }
    }

    Connections {
        target: NetworkService
        function onOnlineChanged() { if (NetworkService.online) root.refresh() }
    }

    SystemClock {
        precision: SystemClock.Enum.Minutes
        onDateChanged: if (root.isRefreshMinute(date.getTime())) root.refresh()
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
