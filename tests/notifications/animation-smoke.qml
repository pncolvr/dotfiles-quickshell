pragma ComponentBehavior: Bound

import QtQuick
import "../../src/theme"

Item {
    id: root
    property var stack: null
    property var nativeHost: null
    property var entries: []
    property bool sharing: false
    property bool allowDuringSharing: false
    readonly property bool motionEnabled: allowDuringSharing || !sharing
    property int step: 0
    property int ticks: 0
    property var firstCard: null
    property var secondCard: null
    property var outgoingCard: null
    property real previousY: 0
    property bool sawOvershoot: false
    property int idleUpdates: 0
    property int motionUpdates: 0
    property real newerGlobalY: 0
    property real surfaceHeight: 0
    property real phaseStarted: 0

    function entry(id, summary) {
        return {liveId: id, emitterKey: "app:animation-test", summary, body: "Sample notification",
            urgency: 1, updatedAt: Date.now(), deadline: 0, duration: 0, actions: [],
            notification: {testNativeObject: true}}
    }
    function check(condition, message) {
        if (condition) return true
        console.error("NOTIFICATION ANIMATION FAIL: " + message)
        ticker.stop()
        Qt.quit()
        return false
    }
    function still() { return !stack.cards.some(card => card.moving) }
    Connections {
        target: root.firstCard
        function onXChanged() { root.motionUpdates++ }
        function onYChanged() { root.motionUpdates++ }
    }
    Timer {
        id: ticker
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            if (!root.stack) return
            if (!root.check(++root.ticks < 600, "animation timed out at step " + root.step)) return
            switch (root.step) {
            case 0:
                root.entries = [root.entry(1, "First")]
                root.firstCard = root.stack.cards[0]
                if (!root.check(root.firstCard.x > 0 && root.firstCard.moving, "new popup starts offscreen to the right")) return
                if (!root.check(!("notification" in root.firstCard.entry), "visual entry does not retain native objects")) return
                root.step++
                break
            case 1:
                if (root.firstCard.x < -0.1) root.sawOvershoot = true
                if (!root.still()) return
                if (!root.check(root.sawOvershoot && Math.abs(root.firstCard.x) < 0.01, "entrance overshoots slightly and settles")) return
                root.entries = [root.entry(1, "First updated")]
                if (!root.check(root.stack.cards[0] === root.firstCard && !root.firstCard.moving
                    && root.firstCard.entry.summary === "First updated", "replacement preserves card identity without another entrance")) return
                root.entries = [root.entry(2, "Second"), root.entries[0]]
                root.secondCard = root.stack.cards.find(card => card.entry.liveId === 2)
                if (!root.check(root.firstCard.y === 0 && root.firstCard.destinationY > 0, "existing card moves down for a new popup")) return
                root.step++
                break
            case 2:
                if (!root.still()) return
                if (!root.check(Math.abs(root.firstCard.y - root.secondCard.height - Theme.notificationSpacing) < 0.01,
                    "stack settles with configured spacing")) return
                root.previousY = root.firstCard.y
                root.outgoingCard = root.secondCard
                root.entries = [root.entries[1]]
                if (!root.check(root.outgoingCard.closing && !root.outgoingCard.enabled && root.stack.cards.length === 2,
                    "removed popup is retained only as a noninteractive closing visual")) return
                if (!root.check(root.firstCard.destinationY === 0 && root.firstCard.y > 0, "gap closes smoothly")) return
                root.step++
                break
            case 3:
                if (!root.outgoingCard || !root.outgoingCard.moving) return
                if (root.outgoingCard.x <= 0 || root.firstCard.y >= root.previousY) return
                if (!root.check(root.outgoingCard.x > 0 && root.firstCard.y < root.previousY,
                    "outgoing card slides right while its neighbour closes the gap")) return
                root.step++
                break
            case 4:
                if (root.stack.cards.length !== 1 || !root.still()) return
                if (!root.check(Math.abs(root.firstCard.y) < 0.01, "remaining card settles at the top")) return
                root.entries = []
                if (!root.check(root.stack.cards.length === 1 && root.stack.implicitHeight > 0,
                    "last card keeps the popup surface sized during exit")) return
                if (root.nativeHost && !root.check(root.nativeHost.visible, "last popup window remains visible during exit")) return
                root.step++
                break
            case 5:
                if (root.stack.cards.length) return
                if (!root.check(root.stack.implicitHeight === 0, "outgoing visuals are released after exit")) return
                if (root.nativeHost && !root.check(!root.nativeHost.visible, "last exit hides the popup window")) return
                root.sharing = true
                root.entries = [root.entry(3, "Sharing")]
                root.firstCard = root.stack.cards[0]
                if (!root.check(root.firstCard.x === 0 && !root.firstCard.moving, "screen sharing disables entrance motion")) return
                root.sharing = false
                if (!root.check(root.firstCard.x === 0 && !root.firstCard.moving, "ending sharing does not replay an existing popup")) return
                root.sharing = true
                root.entries = []
                if (!root.check(root.stack.cards.length === 0, "screen sharing removes popups immediately")) return
                root.allowDuringSharing = true
                root.entries = [root.entry(4, "Override")]
                root.firstCard = root.stack.cards[0]
                if (!root.check(root.firstCard.moving, "configured override allows motion during sharing")) return
                root.step++
                break
            case 6:
                if (root.firstCard.x === root.firstCard.width + root.stack.edgePadding) return
                if (!root.check(root.firstCard.x > 0 && root.firstCard.x < root.firstCard.width + root.stack.edgePadding,
                    "entrance has intermediate rendered positions")) return
                root.allowDuringSharing = false
                if (!root.check(root.firstCard.x === 0 && !root.firstCard.moving, "sharing policy settles an interrupted entrance immediately")) return
                root.sharing = false
                root.entries = [root.entry(5, "Rapid"), root.entries[0]]
                root.outgoingCard = root.stack.cards.find(card => card.entry.liveId === 5)
                root.step++
                break
            case 7:
                root.entries = [root.entries[1]]
                if (!root.check(root.outgoingCard.closing && root.outgoingCard.moving,
                    "dismissal during entrance retargets the current position")) return
                root.step++
                break
            case 8:
                root.sharing = true
                if (!root.check(root.stack.cards.length === 1 && root.firstCard.x === 0 && root.firstCard.y === 0 && !root.firstCard.moving,
                    "sharing policy releases closing visuals and settles layout immediately (cards=" + root.stack.cards.length
                        + ", x=" + root.firstCard.x + ", y=" + root.firstCard.y + ", moving=" + root.firstCard.moving + ")")) return
                root.sharing = false
                root.entries = [root.entry(6, "New"), root.entries[0]]
                root.secondCard = root.stack.cards.find(card => card.entry.liveId === 6)
                root.step++
                break
            case 9:
                if (!root.still()) return
                if (!root.check(root.firstCard.y > 0, "layout binding survives disabling and re-enabling motion")) return
                root.entries = [root.entries[1], root.entries[0]]
                if (!root.check(root.stack.cards.length === 2 && root.firstCard.destinationY === 0,
                    "reordering keeps both card identities")) return
                root.step++
                break
            case 10:
                if (!root.still()) return
                root.entries = []
                if (!root.check(root.stack.cards.length === 2 && root.stack.cards.every(card => card.closing),
                    "bulk dismissal animates every popup")) return
                root.step++
                break
            case 11:
                if (root.stack.cards.length) return
                root.entries = [root.entry(7, "Idle")]
                root.firstCard = root.stack.cards[0]
                root.step++
                break
            case 12:
                if (!root.still()) return
                root.idleUpdates = root.motionUpdates
                root.step++
                break
            case 13:
                if (!root.check(root.idleUpdates === root.motionUpdates, "settled popups perform no idle motion updates")) return
                if (root.nativeHost && !root.check(root.nativeHost.popupStack === root.stack && root.nativeHost.screen
                    && root.nativeHost.width <= root.nativeHost.screen.width && root.nativeHost.height <= root.nativeHost.screen.height,
                    "native popup surface remains bounded")) return
                root.phaseStarted = Date.now()
                root.step++
                break
            case 14:
                if (Date.now() - root.phaseStarted < 1000) return
                root.entries = [root.entry(8, "2"), root.entries[0]]
                root.secondCard = root.stack.cards.find(card => card.entry.liveId === 8)
                root.step++
                break
            case 15:
                if (!root.still()) return
                root.newerGlobalY = root.secondCard.mapToGlobal(0, 0).y
                root.surfaceHeight = root.nativeHost?.height ?? 0
                root.entries = [root.entries[0]]
                root.phaseStarted = Date.now()
                root.step++
                break
            case 16:
                if (root.nativeHost && !root.check(root.nativeHost.height === root.surfaceHeight,
                    "native surface stays fixed when the older bottom popup leaves (height=" + root.nativeHost.height
                        + ", previous=" + root.surfaceHeight + ")")) return
                if (root.nativeHost && !root.check(root.nativeHost.mask.height <= root.stack.height
                    && root.nativeHost.mask.height < root.nativeHost.height, "empty native surface space remains outside the input mask")) return
                if (!root.check(Math.abs(root.secondCard.mapToGlobal(0, 0).y - root.newerGlobalY) < 0.5,
                    "newer popup stays fixed while the older bottom popup leaves (delta="
                        + (root.secondCard.mapToGlobal(0, 0).y - root.newerGlobalY)
                        + ", contentY=" + (root.nativeHost ? root.stack.parent.parent.contentY : "offscreen") + ")")) return
                if (root.stack.cards.length !== 1 || !root.still() || Date.now() - root.phaseStarted < 500) return
                console.log("PASS: notification slides, inertia, stable replacements, gap closure, interruption, sharing policy and idle motion")
                ticker.stop()
                Qt.quit()
                break
            }
        }
    }
}
