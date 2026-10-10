import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/media"
import "../../src/theme/ui" as UI

Scope {
    id: root
    readonly property string phase: Quickshell.env("STORAGE_TEST_PHASE")
    property int step: 0
    property int ticks: 0
    property bool failed: false
    property bool sawAvatarDownload: false
    property bool browserScanRequested: false
    property int layoutTicks: 0
    property int streamResponses: 0
    Test.TestResult { id: objects }
    Connections {
        target: objects.findChild(TwitchService, "twitchStreamsQuery") as Process
        function onExited() { root.streamResponses++ }
    }
    FloatingWindow {
        visible: root.phase === "layout" || root.phase.startsWith("live-")
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        TwitchTooltip { id: panel; width: implicitWidth; height: implicitHeight }
        Twitch { id: twitchModule }
    }

    function check(condition, message) {
        if (condition) return
        failed = true
        console.error("STORAGE FAIL: " + message)
    }

    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }

    function seed() {
        check(DbService.ready, "database created on first use")
        check(DbService.read("SELECT name FROM store.sqlite_master WHERE type = 'table'").length === 10, "central schema")
        check(!TimeService.showSeconds, "default clock preference")
        check(TwitchRepository.exportUsers() === "", "fresh Twitch list is empty")
        check(TwitchService.browserSuggestions.join() === "alice,bob", "current qutebrowser tabs suggested without history or directory pages")
        twitchModule.clicked(null)
        check(TooltipService.pinned && TooltipService.source === twitchModule, "module click pins Twitch like TOTP and notifications")
        TooltipService.hide()
        check(TooltipService.pinned, "pinned Twitch panel ignores hover exit")
        twitchModule.clicked(null)
        check(!TooltipService.pinned, "module click unpins Twitch")
        const field = objects.findChild(panel, "twitchLoginField") as UI.InputField
        const add = objects.findChild(panel, "addTwitchUser") as UI.ActionButton
        const begin = objects.findChild(panel, "beginAddTwitchUser") as UI.ActionButton
        const cancel = objects.findChild(panel, "cancelAddTwitchUser") as UI.ActionButton
        check(!!field && !!add, "dropdown editor exists")
        check(!panel.adding, "editor starts closed")
        const footer = objects.findChild(panel, "twitchEditorFooter") as Item
        const height = footer.height
        begin.clicked()
        check(panel.adding && footer.height === height, "plus opens a single-row channel editor")
        const second = objects.findChild(panel, "twitchSecondChannelField") as UI.InputField
        check(second?.visible && second.placeholderText === "Second channel", "second channel field is immediately available")
        check(second.parent === field.parent && second.y === field.y && second.x >= field.x + field.width
            && second.width === field.width && second.x + second.width <= cancel.parent.x,
            "equally sized channel inputs share a row before cancel and submit buttons")
        check(!objects.findChild(panel, "showTwitchFallbackField"), "no extra button to reveal second channel")
        check(cancel.x < add.x, "cancel is left of submit, as in TOTP")
        field.text = "https://www.twitch.tv/AL"
        check(panel.browserSuggestions.join() === "alice", "browser suggestions filter by typed Twitch URL")
        field.text = "discarded"
        cancel.clicked()
        check(!panel.adding && field.text === "" && TwitchRepository.logins().length === 0, "cancel clears draft without saving")
        begin.clicked()
        field.text = " Alice "
        add.clicked()
        check(!panel.adding && field.text === "" && TwitchRepository.logins().join() === "alice", "dropdown adds normalized login and closes editor")
        check(!TwitchService.addUser("ALICE"), "case insensitive duplicate rejected")
        check(!TwitchService.addUser("bad'; DROP TABLE twitch_users;--"), "invalid login rejected")
        check(TwitchService.browserSuggestions.join() === "bob", "followed streamers excluded from browser suggestions")
        begin.clicked()
        panel.addSuggestion("bob")
        check(!panel.adding && TwitchRepository.logins().includes("bob"), "clicking browser suggestion follows streamer and closes editor")
        check(TwitchService.browserSuggestions.length === 0, "all followed suggestions disappear")
        check(TwitchRepository.exportUsers() === "alice\nbob", "plain sorted export")
        const now = Date.now()
        check(TwitchRepository.saveSchedule("alice", now + 86400000, now), "raw schedule timestamp saved")
        TimeService.showSeconds = true
        check(PreferencesRepository.showSeconds, "clock change persists to repository")
        check(BatteryRepository.saveReceiverSnapshot([{id: "solaar:persist-trackball", name: "Persist trackball", percentage: 17,
            internal: false, state: "discharging", pluggedIn: false, timeToEmpty: 0, timeToFull: 0}]), "battery saved")
        // A partial write must not survive a later failure in the same transaction.
        check(!DbService.write(tx => {
            tx.executeSql("INSERT INTO preferences VALUES (?, ?)", ["rollback.probe", "true"])
            throw new Error("expected rollback")
        }), "failed transaction reported")
        check(DbService.read("SELECT key FROM preferences WHERE key = ?", ["rollback.probe"]).length === 0, "transaction rolled back")
        const duplicate = {id: "duplicate", name: "Duplicate", percentage: 50}
        check(!BatteryRepository.saveReceiverSnapshot([duplicate, duplicate]), "failed SQL write reported")
        check(BatteryRepository.receiverSnapshot()[0]?.percentage === 17, "SQL error rolls back snapshot replacement")
        check(TwitchRepository.imageDataUrl("not an image") === "", "invalid image payload rejected")
        const notification = TwitchService.streamNotification({online: [{login: "a_b", game: "Game", title: "Title"}], offline: [{login: "charlie"}]})
        check(notification.summary === "Live" && notification.body === "`a_b`\n\n**Offline**\n\n`charlie`",
            "mixed status notification contains only headings and literal login names")
        testDates()
    }

    function setupLayout() {
        TooltipService.show(0, null, null, false, {width: 1024, height: 600})
        const users = []
        for (let index = 0; index < 36; index++) {
            users.push({login: "streamer_" + index, online: index < 12, avatar: "",
                game: "Game", viewers: 123, title: "Stream title", nextStream: "tomorrow at 10:00"})
        }
        panel.users = users
        panel.adding = true
    }

    function testLayout() {
        const live = objects.findChild(panel, "twitchLiveUsersSection") as TwitchUserSection
        const offline = objects.findChild(panel, "twitchOfflineUsersSection") as TwitchUserSection
        const grid = objects.findChild(panel, "twitchSuggestionsGrid") as Grid
        const editor = objects.findChild(panel, "twitchEditorControls") as Item
        const footer = objects.findChild(panel, "twitchEditorFooter") as Item
        const usersView = objects.findChild(panel, "twitchUsersScrollView") as QC.ScrollView
        const field = objects.findChild(panel, "twitchLoginField") as UI.InputField
        const bulk = objects.findChild(panel, "addAllBrowserTwitchUsers") as UI.ActionButton
        const search = objects.findChild(panel, "twitchSearchField") as UI.SearchField
        const initialWidth = panel.implicitWidth
        panel.adding = false
        search.text = " STREAMER_1 "
        check(panel.liveUsers.length === 3 && panel.offlineUsers.length === 8, "search matches login without case or surrounding spaces")
        check(offline.showingUsers && !offline.expanded, "search reveals Offline matches without changing its collapse state")
        check(panel.implicitWidth === initialWidth, "search does not resize the tooltip width")
        search.text = "game"
        check(panel.filteredUsers.length === 36, "search matches cached categories")
        search.text = "stream title"
        check(panel.filteredUsers.length === 36, "search matches cached stream titles")
        search.text = "no matching streamer"
        check(!panel.filteredUsers.length && root.find(panel, "twitchSearchEmpty").visible, "unmatched search has an empty state")
        search.text = "streamer_1"
        panel.adding = true
        check(!search.visible && panel.filteredUsers.length === 36, "add form hides and suspends search")
        panel.cancelEditor()
        check(search.visible && search.text === "streamer_1" && panel.filteredUsers.length === 11, "returning from add preserves search")
        const clear = root.find(search, "clearSearch") as UI.ActionButton
        clear.clicked()
        check(search.text === "" && search.activeFocus && !offline.showingUsers, "clear button restores all users and keeps input focus")
        panel.adding = true
        check(live.users.length === 12 && live.users.every(user => user.online), "Live grid contains only live users")
        check(offline.users.length === 24 && offline.users.every(user => !user.online), "Offline grid contains only offline users")
        check(live.expanded && !offline.expanded, "Live starts expanded and Offline starts collapsed")
        check(live.columns === 1 && offline.columns === 1, "sections show one streamer per row")
        check(grid.columns === 2, "suggestions form a compact grid on wide tooltips")
        check(panel.implicitHeight <= panel.maximumHeight + 1, "entire tooltip respects screen height cap")
        check(editor.width === footer.width && footer.y + footer.height <= panel.height, "add controls fill the footer and remain on screen")
        check(usersView.contentHeight > usersView.height, "large followed list scrolls within its budget")
        check(field.placeholderText === "Twitch channel", "main field is distinguished from second channel")
        check(bulk.label === "Add all (2)", "bulk count matches displayed suggestions")
        field.text = "bo"
        check(bulk.label === "Add all (1)", "bulk count follows the search filter")
        const bob = root.find(panel, "addBrowserTwitchUser_bob") as UI.ActionButton
        check(!!bob, "browser suggestion renders as an add button")
        if (!bob) return
        bob.clicked()
        check(panel.adding && field.text === "bo", "individual suggestion preserves editor and search while other suggestions remain")
        field.clear()
        bulk.clicked()
        check(!panel.adding && TwitchRepository.exportUsers() === "alice\nbob", "bulk action snapshots and adds remaining suggestions")
        check(TwitchService.removeUser("alice") && TwitchService.removeUser("bob"), "layout fixture users removed")
        check(TwitchService.removedUsers.map(entry => entry.login).join() === "alice,bob", "all removals remain available in the undo array")
        const allUndo = objects.findChild(panel, "undoAllTwitchUsers") as UI.ActionButton
        check(allUndo.label === "Undo all (2)", "undo count matches pending removals")
        check(TwitchService.undoRemoveUser("alice") && TwitchService.removedUsers.map(entry => entry.login).join() === "bob", "individual Undo retains other pending removals")
        check(TwitchService.removeUser("alice") && TwitchService.removedUsers.length === 2, "a repeated removal gets a new undo entry")
        allUndo.clicked()
        check(!TwitchService.removedUsers.length && TwitchRepository.exportUsers() === "alice\nbob", "Undo all snapshots and restores every removal")
        check(TwitchService.removeUser("alice") && TwitchService.removeUser("bob"), "restored layout users cleaned up")
        const expiry = objects.findChild(TwitchRepository, "twitchUndoExpiry") as Timer
        check(expiry.interval > 5900 && expiry.interval <= 6000, "earliest removal expires after six seconds")
        TwitchRepository.removedUsers[0].expiresAt = Date.now() + 50
        TwitchRepository.removedUsers[1].expiresAt = Date.now() + 200
        TwitchRepository.pruneUndo()
    }

    function testUndo() {
        const user = TwitchRepository.users.find(user => user.login === "alice")
        const schedule = TwitchRepository.schedules.alice
        const avatar = TwitchRepository.avatars.alice
        check(TwitchService.removeUser("alice"), "streamer removed with Undo available")
        check(TwitchService.removedUsers.length === 1 && TwitchService.removedUsers[0].login === "alice" && !TwitchRepository.avatars.alice && !TwitchRepository.schedules.alice,
            "removal clears caches while retaining an undo snapshot")
        check(TwitchService.undoRemoveUser("alice"), "individual undo restores requested streamer")
        check(TwitchRepository.users.find(entry => entry.login === "alice")?.addedAt === user.addedAt, "Undo restores original user metadata")
        check(TwitchRepository.schedules.alice?.startsAt === schedule.startsAt && TwitchRepository.schedules.alice?.fetchedAt === schedule.fetchedAt,
            "Undo restores schedule cache")
        check(TwitchRepository.avatars.alice?.dataUrl === avatar.dataUrl && TwitchRepository.avatars.alice?.sourceUrl === avatar.sourceUrl,
            "Undo restores avatar payload")
        check(!TwitchService.removedUsers.length && !TwitchService.undoRemoveUser("alice"), "Undo is consumed after restore")
    }

    function testDates() {
        const fiveMinutes = 5 * 60 * 1000
        const sevenMinutes = 7 * 60 * 1000
        check(TwitchService.isRefreshMinute(new Date(2026, 9, 6, 10, 0).getTime(), fiveMinutes)
            && TwitchService.isRefreshMinute(new Date(2026, 9, 6, 10, 5).getTime(), fiveMinutes)
            && TwitchService.isRefreshMinute(new Date(2026, 9, 6, 10, 55).getTime(), fiveMinutes), "five-minute polls align with clock minutes")
        check(!TwitchService.isRefreshMinute(new Date(2026, 9, 6, 10, 3).getTime(), fiveMinutes), "startup minute does not shift regular polls")
        check(TwitchService.isRefreshMinute(new Date(2026, 9, 6, 10, 7).getTime(), sevenMinutes)
            && TwitchService.isRefreshMinute(new Date(2026, 9, 6, 10, 56).getTime(), sevenMinutes)
            && TwitchService.isRefreshMinute(new Date(2026, 9, 6, 11, 0).getTime(), sevenMinutes)
            && !TwitchService.isRefreshMinute(new Date(2026, 9, 6, 11, 3).getTime(), sevenMinutes), "configured poll minutes restart each hour")
        const midnightBefore = new Date(2026, 9, 4, 23, 59).getTime()
        const midnightAfter = new Date(2026, 9, 5, 0, 1).getTime()
        const starts = new Date(2026, 9, 5, 10, 0).getTime()
        const users = [{login: "alice", nextStreamAt: starts}]
        check(TwitchService.formatOfflineUsers(users, midnightBefore)[0].nextStream === "tomorrow at 10:00", "tomorrow before midnight")
        check(TwitchService.formatOfflineUsers(users, midnightAfter)[0].nextStream === "today at 10:00", "today after midnight without fetching")
        check(TwitchService.formatOfflineUsers(users, starts)[0].nextStream === "", "past schedules disappear")
        check(CalendarService.formatDate("invalid", midnightBefore) === "", "invalid timestamp ignored")
        check(TwitchService.nextScheduledStream([
            {start_time: new Date(starts + 2000).toISOString()},
            {start_time: new Date(starts).toISOString(), canceled_until: "canceled"},
            {start_time: "invalid"}, {start_time: new Date(starts + 1000).toISOString()}
        ], midnightBefore) === starts + 1000, "first valid future noncancelled segment")
        check(TwitchService.scheduleIsFresh({startsAt: starts, fetchedAt: midnightBefore}, midnightBefore), "fresh schedule reused")
        check(!TwitchService.scheduleIsFresh({startsAt: starts, fetchedAt: midnightBefore}, midnightBefore + 3600000), "one hour TTL expires")
        check(!TwitchService.scheduleIsFresh({startsAt: midnightBefore, fetchedAt: midnightBefore}, midnightBefore), "elapsed start forces refresh")
    }

    Timer {
        id: ticker
        interval: 25
        repeat: true
        running: true
        onTriggered: {
            if (++root.ticks > 300 || root.failed) {
                root.check(false, "failed or timed out in " + root.phase + " at step " + root.step)
                ticker.stop()
                Qt.quit()
                return
            }
            if (root.step === 0) {
                if (!DbService.ready || !TwitchService.available || (root.phase !== "layout" && !NetworkService.online)) return
                if (root.phase === "seed" || root.phase === "layout" || root.phase === "live-add") {
                    if (!root.browserScanRequested) {
                        root.browserScanRequested = true
                        TwitchService.refreshBrowserSuggestions()
                        return
                    }
                    if (TwitchService.browserSuggestions.length !== 2) return
                }
                if (root.phase === "seed") root.seed()
                else if (root.phase === "layout") root.setupLayout()
                else if (root.phase === "live-add") {
                    root.check(!TwitchService.hasOnline && !panel.liveUsers.length, "bulk add starts with no live streamers")
                    panel.adding = true
                    panel.addAllSuggestions()
                    root.check(TwitchRepository.exportUsers() === "alice\nbob", "bulk add stores every suggested streamer")
                }
                else if (root.phase === "live-restart" || root.phase === "live-new-stream") {
                    if (root.phase === "live-restart") root.check(TwitchRepository.notifiedStreams.alice?.streamId === "alice-stream-1"
                        && TwitchRepository.notifiedStreams.bob?.streamId === "bob-stream-1", "last notified streams restored after restart")
                }
                else if (["live-error", "live-offline", "live-offline-restart"].includes(root.phase)) {
                    root.check(TwitchRepository.notifiedStreams.alice?.streamId === "alice-stream-2"
                        && TwitchRepository.notifiedStreams.bob?.streamId === "bob-stream-1", "latest streams restored before offline check")
                }
                else if (root.phase === "restart") {
                    root.check(DbService.schemaVersion === 7
                        && DbService.read("SELECT login FROM twitch_notified_streams").length === 0, "v3 schema upgraded without losing existing data")
                    root.check(TimeService.showSeconds, "clock preference restored after process restart")
                    root.check(TwitchRepository.exportUsers() === "alice\nbob", "Twitch users restored after process restart")
                    root.check(BatteryService.receiverBatteries[0]?.percentage === 17, "battery restored before new scan")
                    root.check(!!TwitchRepository.schedules.alice?.startsAt, "schedule timestamp restored")
                    root.check(TwitchRepository.avatars.alice?.dataUrl.startsWith("data:image/png;base64,"), "avatar bytes restored from database")
                } else if (root.phase === "avatar-failure" || root.phase === "avatar-update") {
                    root.check(TwitchRepository.avatars.alice?.sourceUrl === "https://avatars.test/alice.png", "previous avatar initially available")
                } else if (root.phase === "empty") {
                    const remove = root.find(panel, "removeTwitchUser_alice") as UI.ActionButton
                    root.check(!!remove, "dropdown remove control exists")
                    if (!remove) return
                    remove.clicked()
                    root.check(!TwitchRepository.schedules.alice, "removal deletes schedule cache")
                    root.check(!TwitchRepository.avatars.alice, "removal deletes avatar payload")
                    root.check(!TwitchRepository.saveSchedule("alice", Date.now() + 1000, Date.now()), "in-flight response cannot recreate removed cache")
                    root.check(!TwitchRepository.saveAvatar("alice", "removed", "iVBORw0KGgo=", Date.now()), "in-flight avatar cannot recreate removed payload")
                    root.check(TwitchService.removeUser("bob"), "service removes remaining user")
                    root.check(TwitchRepository.exportUsers() === "", "empty list exports empty text")
                    TimeService.showSeconds = false
                    root.check(BatteryRepository.saveReceiverSnapshot([]), "confirmed empty snapshot persisted")
                } else {
                    root.check(TwitchRepository.logins().length === 0, "empty list remains empty after restart")
                    root.check(!TimeService.showSeconds, "disabled seconds persists")
                    root.check(BatteryRepository.receiverSnapshot().length === 0, "disconnected batteries remain removed after restart")
                }
                root.step++
                return
            }
            if (root.phase === "seed") {
                if (!TwitchRepository.schedules.bob || !TwitchRepository.avatars.alice || !TwitchRepository.avatars.bob) return
                root.check(TwitchService.offlineUsers.find(user => user.login === "bob")?.nextStream.length > 0, "API schedule saved and displayed")
                const image = root.find(panel, "twitchAvatar_alice")
                if (image?.status === Image.Loading) return
                root.check(image?.status === Image.Ready, "QML displays image directly from SQLite payload")
                root.testUndo()
            } else if (["live-add", "live-restart", "live-new-stream"].includes(root.phase)) {
                if (TwitchService.onlineUsers.length !== 2 || !TwitchRepository.avatars.alice || !TwitchRepository.avatars.bob || ++root.layoutTicks < 4) return
                const live = objects.findChild(panel, "twitchLiveUsersSection") as TwitchUserSection
                const grid = objects.findChild(live, "twitchUserSectionGrid") as Grid
                const usersView = objects.findChild(panel, "twitchUsersScrollView") as QC.ScrollView
                root.check(live.visible && live.expanded && grid.visible && grid.implicitHeight > 0 && usersView.height > 0,
                    "Live section appears after bulk adding streamers to an empty live list")
                root.check(live.height > 0 && panel.implicitHeight > 50, "Live section participates in the tooltip layout")
                root.check(TwitchRepository.notifiedStreams.alice?.streamId === (root.phase === "live-new-stream" ? "alice-stream-2" : "alice-stream-1")
                    && TwitchRepository.notifiedStreams.bob?.streamId === "bob-stream-1", "notified stream identities saved")
                root.check(DbService.read("SELECT login FROM twitch_notified_streams").length === 2,
                    "only one notified stream per followed user, including after a new stream")
            } else if (["live-error", "live-offline", "live-offline-restart"].includes(root.phase)) {
                if (root.streamResponses < 1 || ++root.layoutTicks < 4) return
                const expectedOnline = root.phase === "live-error"
                root.check(TwitchRepository.notifiedStreams.alice?.online === expectedOnline
                    && TwitchRepository.notifiedStreams.bob?.online === expectedOnline,
                    "failed requests preserve online state; successful offline checks persist it")
                root.check(DbService.read("SELECT login FROM twitch_notified_streams").length === 2, "offline records remain bounded")
                if (root.phase === "live-offline-restart") {
                    root.check(TwitchService.removeUser("alice") && !TwitchRepository.notifiedStreams.alice, "removal clears notified stream")
                    root.check(TwitchService.undoRemoveUser("alice") && TwitchRepository.notifiedStreams.alice?.streamId === "alice-stream-2"
                        && !TwitchRepository.notifiedStreams.alice?.online,
                        "undo restores notified stream without repeating its alert")
                    TwitchService.removeUser("alice")
                    TwitchService.removeUser("bob")
                }
            } else if (root.phase === "layout") {
                if (root.step === 1) {
                    if (++root.layoutTicks < 4) return
                    root.testLayout()
                    root.step++
                    return
                }
                if (root.step === 2) {
                    if (TwitchService.removedUsers.length === 2) return
                    root.check(TwitchService.removedUsers.length === 1 && TwitchService.removedUsers[0].login === "bob", "each removal expires independently")
                    root.check(!TwitchService.undoRemoveUser("alice"), "expired individual Undo cannot restore a user")
                    root.step++
                }
                if (TwitchService.removedUsers.length) return
                root.check(!TwitchService.undoRemoveUser("bob") && TwitchRepository.logins().length === 0, "expired Undo cannot restore removed users")
            } else if (root.phase === "restart") {
                if (BatteryService.scanningReceivers) return
                root.check(!!BatteryService.receiverError && BatteryService.receiverBatteries[0]?.percentage === 17, "failed restart scan retains cached reading")
            } else if (root.phase === "avatar-failure" || root.phase === "avatar-update") {
                const process = objects.findChild(TwitchService, "twitchAvatarDownload") as Process
                if (process.running) { root.sawAvatarDownload = true; return }
                if (!root.sawAvatarDownload) return
                const expectedUrl = root.phase === "avatar-failure" ? "https://avatars.test/alice.png" : "https://avatars.test/alice-v2.png"
                root.check(TwitchRepository.avatars.alice?.sourceUrl === expectedUrl, "failed download keeps cache; changed image replaces cache after success")
            }
            if (!root.failed) console.log("PASS: storage " + root.phase)
            ticker.stop()
            Qt.quit()
        }
    }
}
