pragma ComponentBehavior: Bound

import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/media"
import "../../src/theme/ui" as UI

Scope {
    id: root
    readonly property string phase: Quickshell.env("TWITCH_FALLBACK_PHASE")
    property int ticks: 0
    property int step: 0
    property bool failed: false
    property int streamResponses: 0
    property int responseBaseline: 0
    Test.TestResult { id: objects }
    Test.TestEvent { id: events }
    Connections {
        target: objects.findChild(TwitchService, "twitchStreamsQuery") as Process
        function onExited() { root.streamResponses++ }
    }
    Process {
        id: failNextBatch
        command: ["touch", Quickshell.env("TWITCH_FALLBACK_STATE") + "/fail-batch"]
        onExited: TwitchService.refresh()
    }
    FloatingWindow {
        visible: true
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        TwitchTooltip { id: panel; width: implicitWidth; height: implicitHeight }
    }
    function check(condition, message) {
        if (condition) return
        failed = true
        console.error("FALLBACK FAIL: " + message)
    }
    function find(name, item = panel) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const found = find(name, child)
            if (found) return found
        }
        return null
    }
    function mainEntry() { return TwitchService.allUsers.find(user => user.mainLogin === "banana") }
    function link() {
        check(DbService.schemaVersion === 7 && TwitchRepository.logins().join() === "banana,tomato", "v6 upgrade preserves existing entries")
        check(TwitchRepository.users.every(user => user.fallbackLogin === ""), "migration defaults to no fallback")
        find("editTwitchUser_banana").clicked()
        const main = find("twitchLoginField") as UI.InputField
        const fallback = find("twitchSecondChannelField") as UI.InputField
        check(panel.adding && panel.editingLogin === "banana" && main.text === "banana", "row action fills shared editor")
        check(TwitchService.addUser("https://www.twitch.tv/Potato"), "independent fallback added")
        check(!TwitchService.updateUser("banana", "banana", "potato"), "linking requires explicit action")
        check(TwitchRepository.logins().join() === "banana,potato,tomato", "rejected linking preserves separate entries")
        check(find("twitchSecondChannelField").visible, "row edit button reveals second channel field directly")
        fallback.text = "https://m.twitch.tv/POTATO"
        check(!find("addTwitchUser").enabled && find("linkTwitchEntries").visible, "already followed channel requires Link these entries")
        find("linkTwitchEntries").clicked()
        check(!panel.adding && TwitchRepository.logins().join() === "banana,tomato", "explicit linking merges entries and closes editor")
        check(TwitchRepository.users[0].fallbackLogin === "potato", "fallback saved against main")
        check(!TwitchService.addUser("potato"), "associated channel cannot be followed twice")
        check(!TwitchService.updateUser("tomato", "tomato", "potato"), "fallback cannot be shared by entries")
        check(!TwitchService.updateUser("banana", "banana", "banana"), "self link rejected")
        check(!TwitchService.updateUser("banana", "banana", "bad'; DROP TABLE twitch_users;--"), "invalid fallback rejected")
        check(TwitchRepository.reload() && TwitchRepository.users[0].fallbackLogin === "potato", "association survives repository reload")
    }
    function selection() {
        const user = mainEntry()
        check(TwitchService.allUsers.length === 2, "one entry per followed streamer")
        if (["link", "both", "main"].includes(phase)) {
            check(user.login === "banana" && user.online && !user.usingFallback, "main wins whenever it is live")
            check(user.title === "banana title" && user.game === "banana game", "main stream metadata displayed")
        } else if (phase === "fallback" || phase === "fallback-restart") {
            check(user.login === "potato" && user.online && user.usingFallback, "live fallback selected when main is offline")
            check(user.title === "potato title" && user.game === "potato game" && user.avatar === TwitchRepository.avatars.potato.dataUrl, "fallback metadata and avatar displayed")
            const label = find("twitchSecondChannelLabel_banana") as UI.ColumnText
            check(label?.visible && label.text === "Second channel for banana", "fallback relationship displayed")
            if (phase === "fallback") {
                check(events.mouseClick(label, label.width / 2, label.height / 2, Qt.LeftButton, Qt.NoModifier, 0), "main-channel label receives pointer click")
                const details = find("twitchUserDetails_banana") as Item
                check(events.mouseClick(details, 10, 10, Qt.LeftButton, Qt.NoModifier, 0), "stream details receive pointer click")
                const avatar = find("twitchAvatar_potato").parent
                check(events.mouseClick(avatar, avatar.width / 2, avatar.height / 2, Qt.LeftButton, Qt.NoModifier, 0), "displayed avatar receives pointer click")
            }
        } else if (phase === "neither") {
            check(user.login === "banana" && !user.online && !user.usingFallback, "neither live leaves only main in Offline")
            check(TwitchService.onlineUsers.length === 1 && TwitchService.offlineUsers.length === 1, "counts track associations, not channels")
        }
        panel.searchText = "potato"
        check(panel.filteredUsers.length === 1 && panel.filteredUsers[0].mainLogin === "banana", "search finds main by fallback name in either status")
        panel.searchText = "banana"
        check(panel.filteredUsers.length === 1, "search finds main while fallback is displayed")
        panel.searchText = ""
        check(!TwitchRepository.notifiedStreams.potato, "fallback does not retain independent alerts")
    }
    function editing() {
        find("beginAddTwitchUser").clicked()
        find("twitchLoginField").text = "lettuce"
        find("twitchSecondChannelField").text = "pepper"
        check(find("twitchSecondChannelField").visible && !panel.hasSuggestions, "second channel is available while adding; paired draft hides single-channel suggestions")
        find("addTwitchUser").clicked()
        check(TwitchRepository.users.some(user => user.login === "lettuce" && user.fallbackLogin === "pepper") && !panel.adding, "add form saves both channels without a reveal button")
        check(TwitchService.removeUser("lettuce"), "temporary association removed")
        const original = TwitchRepository.users[0]
        const mainAvatar = TwitchRepository.avatars.banana
        const fallbackAvatar = TwitchRepository.avatars.potato
        find("removeTwitchUser_banana").clicked()
        check(!TwitchRepository.channelLogins().includes("potato") && !TwitchRepository.avatars.potato, "row Remove deletes main association and fallback cache")
        check(TwitchService.undoRemoveUser("banana"), "Undo restores association")
        check(TwitchRepository.users[0].fallbackLogin === "potato" && TwitchRepository.users[0].addedAt === original.addedAt, "Undo restores metadata and fallback")
        check(TwitchRepository.avatars.banana?.dataUrl === mainAvatar.dataUrl && TwitchRepository.avatars.potato?.dataUrl === fallbackAvatar.dataUrl, "Undo restores both avatars")
        panel.editUser("banana")
        check(find("twitchSecondChannelField").visible && find("twitchSecondChannelField").text === "potato", "editing fills existing fallback")
        find("twitchSecondChannelField").text = ""
        find("addTwitchUser").clicked()
        check(TwitchRepository.users[0].fallbackLogin === "" && !TwitchRepository.avatars.potato, "clearing fallback unlinks it and removes unused cache")
        check(TwitchService.addUser("potato"), "unlinked channel may be followed independently")
        check(!TwitchService.updateUser("banana", "banana", "tomato") && TwitchRepository.logins().length === 3, "ordinary save cannot consume another entry")
        check(TwitchService.updateUser("banana", "Banana", "potato", true), "explicit relinking works")
        check(!TwitchService.addUser("cucumber", "banana", true), "nested association rejected")
        panel.editUser("banana")
        find("twitchLoginField").text = "changed"
        find("cancelAddTwitchUser").clicked()
        check(TwitchRepository.users[0].login === "banana" && !panel.editingLogin && !find("twitchSecondChannelField").visible, "Cancel discards all draft fields")
        check(TwitchService.updateUser("banana", "https://twitch.tv/Cucumber", "potato"), "main rename accepts Twitch URL")
        check(!TwitchRepository.channelLogins().includes("banana") && TwitchRepository.users[0].login === "cucumber", "main rename removes old identity")
        check(TwitchService.removeUser("cucumber") && TwitchService.addUser("potato"), "released fallback can be reused")
        check(!TwitchService.undoRemoveUser("cucumber") && TwitchRepository.logins().includes("potato"), "Undo cannot overwrite a reused channel")
    }
    Timer {
        id: buttonCheck
        interval: 50
        onTriggered: {
            const edit = root.find("editTwitchUser_banana") as UI.ActionButton
            root.check(events.mouseClick(edit, edit.width / 2, edit.height / 2, Qt.LeftButton, Qt.NoModifier, 0), "edit button receives a real pointer click")
            root.check(panel.editingLogin === "banana" && panel.adding && root.find("twitchSecondChannelField").visible
                && root.find("twitchSecondChannelField").text === "potato", "clicking edit opens the populated channel editor")
            root.find("twitchLoginField").text = "discarded"
            root.check(events.mouseClick(edit, edit.width / 2, edit.height / 2, Qt.LeftButton, Qt.NoModifier, 0), "edit button receives second pointer click")
            root.check(!panel.adding && !panel.editingLogin && root.find("twitchLoginField").text === ""
                && root.find("twitchSecondChannelField").text === "", "clicking same edit button closes editor and clears draft")
            root.check(TwitchRepository.users.some(user => user.login === "banana" && user.fallbackLogin === "potato"), "closing editor preserves saved channels")
            if (!root.failed) console.log("PASS: fallback both")
            Qt.quit()
        }
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (++root.ticks > 320 || root.failed) {
                if (!root.failed) console.error("FALLBACK FAIL: timeout " + root.phase + " step=" + root.step
                    + " entries=" + JSON.stringify(TwitchService.allUsers) + " users=" + JSON.stringify(TwitchRepository.users))
                Qt.quit()
                return
            }
            if (!DbService.ready || !TwitchService.available || !NetworkService.online) return
            if (root.step === 0) {
                if (root.phase === "batch") {
                    root.check(TwitchRepository.channelLogins().length === 102, "batch fixture has more than 100 channels")
                    root.step = 1
                    return
                }
                if (!root.find("twitchUserRow_banana")) return
                if (root.phase === "link") root.link()
                else root.check(TwitchRepository.users[0].fallbackLogin === "potato", "association survives process restart")
                root.step = 1
                return
            }
            if (root.phase === "batch") {
                if (root.step === 1) {
                    if (Object.keys(TwitchRepository.avatars).length !== 102 || TwitchService.onlineUsers.length !== 51) return
                    root.check(TwitchService.onlineUsers.every(user => user.login === user.mainLogin && !user.usingFallback), "both API batches honor main-channel priority")
                    root.responseBaseline = root.streamResponses
                    root.step = 2
                    failNextBatch.running = true
                } else if (root.streamResponses >= root.responseBaseline + 2) {
                    root.check(TwitchService.onlineUsers.length === 51, "failed second batch preserves the complete previous live snapshot")
                    if (!root.failed) console.log("PASS: fallback batch")
                    stop()
                    Qt.quit()
                }
                return
            }
            if (!TwitchRepository.avatars.banana || !TwitchRepository.avatars.potato || !TwitchRepository.avatars.tomato
                || !TwitchRepository.schedules.banana && ["fallback", "fallback-restart", "neither"].includes(root.phase)) return
            const expected = ["link", "both", "main"].includes(root.phase) ? "banana" : ["fallback", "fallback-restart"].includes(root.phase) ? "potato" : "banana"
            const user = root.mainEntry()
            if (!user || user.login !== expected || TwitchService.onlineUsers.length !== (root.phase === "neither" ? 1 : 2)) return
            // Allow row delegates and queued notifications to settle.
            if (++root.step < 5) return
            root.selection()
            if (root.phase === "edit") root.editing()
            if (root.phase === "both" && !root.failed) {
                stop()
                buttonCheck.start()
                return
            }
            if (!root.failed) console.log("PASS: fallback " + root.phase)
            stop()
            Qt.quit()
        }
    }
}
