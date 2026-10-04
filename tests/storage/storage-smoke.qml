import QtQuick
import QtTest as Test
import Quickshell
import "../../services"
import "../../modules/media"

Scope {
    id: root
    readonly property string phase: Quickshell.env("STORAGE_TEST_PHASE")
    property int step: 0
    property int ticks: 0
    property bool failed: false
    property bool sawAvatarDownload: false
    Test.TestResult { id: objects }
    FloatingWindow {
        visible: false
        TwitchTooltip { id: panel }
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
        check(DbService.read("SELECT name FROM store.sqlite_master WHERE type = 'table'").length === 5, "central schema")
        check(!TimeService.showSeconds, "default clock preference")
        check(TwitchRepository.exportUsers() === "", "fresh Twitch list is empty")
        const field = objects.findChild(panel, "twitchLoginField")
        const add = objects.findChild(panel, "addTwitchUser")
        const begin = objects.findChild(panel, "beginAddTwitchUser")
        const cancel = objects.findChild(panel, "cancelAddTwitchUser")
        check(!!field && !!add, "dropdown editor exists")
        check(!panel.adding, "editor starts closed")
        const height = panel.implicitHeight
        begin.clicked()
        check(panel.adding && panel.implicitHeight === height, "plus opens editor without resizing footer")
        check(cancel.x < add.x, "cancel is left of submit, as in TOTP")
        field.text = "discarded"
        cancel.clicked()
        check(!panel.adding && field.text === "" && TwitchRepository.logins().length === 0, "cancel clears draft without saving")
        begin.clicked()
        field.text = " Alice "
        add.clicked()
        check(!panel.adding && field.text === "" && TwitchRepository.logins().join() === "alice", "dropdown adds normalized login and closes editor")
        check(!TwitchService.addUser("ALICE"), "case insensitive duplicate rejected")
        check(!TwitchService.addUser("bad'; DROP TABLE twitch_users;--"), "invalid login rejected")
        check(TwitchService.addUser("bob"), "service adds a login")
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
        testDates()
    }

    function testDates() {
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
                if (!DbService.ready || !TwitchService.available || !NetworkService.online) return
                if (root.phase === "seed") root.seed()
                else if (root.phase === "restart") {
                    root.check(TimeService.showSeconds, "clock preference restored after process restart")
                    root.check(TwitchRepository.exportUsers() === "alice\nbob", "Twitch users restored after process restart")
                    root.check(BatteryService.receiverBatteries[0]?.percentage === 17, "battery restored before new scan")
                    root.check(!!TwitchRepository.schedules.alice?.startsAt, "schedule timestamp restored")
                    root.check(TwitchRepository.avatars.alice?.dataUrl.startsWith("data:image/png;base64,"), "avatar bytes restored from database")
                } else if (root.phase === "avatar-failure" || root.phase === "avatar-update") {
                    root.check(TwitchRepository.avatars.alice?.sourceUrl === "https://avatars.test/alice.png", "previous avatar initially available")
                } else if (root.phase === "empty") {
                    const remove = root.find(panel, "removeTwitchUser_alice")
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
            } else if (root.phase === "restart") {
                if (BatteryService.scanningReceivers) return
                root.check(!!BatteryService.receiverError && BatteryService.receiverBatteries[0]?.percentage === 17, "failed restart scan retains cached reading")
            } else if (root.phase === "avatar-failure" || root.phase === "avatar-update") {
                const process = objects.findChild(TwitchService, "twitchAvatarDownload")
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
