pragma ComponentBehavior: Bound

import QtQuick
import "../../../ui" as UI
import "../../../theme"

Item {
    id: root
    property var entries: []
    property bool animationsEnabled: UI.MotionPolicy.enabled
    property real edgePadding: 24
    property var cards: []
    property bool initialized: false
    implicitHeight: cards.reduce((height, card) => Math.max(height, card.y + card.height,
        card.destinationY + card.height), 0)

    function visualEntry(entry) {
        const snapshot = Object.assign({}, entry)
        // Closing visuals must not retain native notification objects or callbacks.
        delete snapshot.notification
        return snapshot
    }
    function layoutCards() {
        let position = 0
        for (const entry of entries) {
            const card = cards.find(item => item.entry.liveId === entry.liveId && !item.closing)
            if (!card) continue
            card.destinationY = position
            position += card.height + Theme.notificationSpacing
        }
    }
    function retire(card) {
        cards = cards.filter(item => item !== card)
        card.destroy()
    }
    function synchronize() {
        if (!initialized) return
        for (const card of cards.slice()) {
            if (!card.closing && !entries.some(entry => entry.liveId === card.entry.liveId)) card.leave()
        }
        for (const entry of entries) {
            const existing = cards.find(card => card.entry.liveId === entry.liveId && !card.closing)
            if (existing) existing.entry = visualEntry(entry)
            else {
                const card = popupCard.createObject(root, {entry: visualEntry(entry)})
                cards = cards.concat([card])
            }
        }
        layoutCards()
        for (const card of cards) card.layoutReady = true
    }
    function settle() {
        for (const card of cards.slice()) {
            if (card.closing) retire(card)
            else card.finishMotion()
        }
    }
    onEntriesChanged: synchronize()
    onAnimationsEnabledChanged: if (!animationsEnabled) settle()
    Component.onCompleted: { initialized = true; synchronize() }

    Component {
        id: popupCard
        NotificationCard {
            id: card
            popup: true
            width: root.width
            property bool layoutReady: false
            property real destinationY: 0
            property real slideProgress: 1
            readonly property bool moving: entrance.running || departure.running || placement.running
            x: (width + root.edgePadding) * slideProgress
            z: closing ? 0 : 1
            onHeightChanged: root.layoutCards()
            onDestinationYChanged: {
                placement.stop()
                if (root.animationsEnabled && layoutReady) {
                    placement.to = destinationY
                    placement.start()
                } else y = destinationY
            }
            function leave() {
                closing = true
                entrance.stop()
                if (root.animationsEnabled) departure.restart()
                else root.retire(card)
            }
            function finishMotion() {
                entrance.stop()
                departure.stop()
                placement.stop()
                slideProgress = 0
                y = destinationY
            }
            Component.onCompleted: {
                if (root.animationsEnabled) entrance.start()
                else slideProgress = 0
            }
            UI.MotionAnimation {
                id: placement
                target: card
                property: "y"
                animationDuration: Theme.notificationMoveDuration
                easing.type: Easing.OutCubic
            }
            UI.MotionAnimation {
                id: entrance
                target: card
                property: "slideProgress"
                to: 0
                animationDuration: Theme.notificationEnterDuration
                easing.type: Easing.OutBack
                easing.overshoot: 0.8
            }
            UI.MotionAnimation {
                id: departure
                target: card
                property: "slideProgress"
                to: 1
                animationDuration: Theme.notificationExitDuration
                easing.type: Easing.InCubic
                onFinished: root.retire(card)
            }
        }
    }
}
