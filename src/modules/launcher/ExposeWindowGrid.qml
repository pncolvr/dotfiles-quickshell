pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI

Flickable {
    id: root
    required property var picker
    property real transitionProgress: 1
    property string captureAddress: ""
    required property Item dragLayer
    property var entries: picker.filteredItems
    property var arrangedEntries: []
    property bool modelReady: false
    property bool animationsEnabled: true
    property int displayedWorkspace: -1
    property int workspaceDirection: 1
    property real workspaceProgress: 1
    property var outgoingCards: []
    property string dragAddress: ""
    property bool dragVacated: false
    readonly property bool animateLayout: modelReady && animationsEnabled && transitionProgress === 1
        && displayedWorkspace === picker.exposeWorkspace && !workspaceAnimation.running
    readonly property var layoutEntries: arrangedEntries.filter(entry => {
        if (dragVacated && entry.id === dragAddress) return false
        const destination = picker.exposePendingMoves?.[entry.id]
        return destination === undefined || (picker.exposeWorkspace !== 0 && entry.workspaceId === destination)
    })
    readonly property int count: entries.length
    readonly property int layoutCount: layoutEntries.length
    readonly property int currentIndex: picker.currentIndex
    readonly property int columns: arrangement.columns
    readonly property var arrangement: {
        if (!layoutCount || width <= 0 || height <= 0) return {columns: 1, cards: [], byId: {}, height: 0}
        const spacing = Theme.exposeSpacing
        const horizontalPadding = Theme.controlSpacing * 2
        const verticalPadding = Theme.controlHeight + Theme.controlSpacing + 1
        const sizes = layoutEntries.map(entry => ({
            width: entry.client?.size?.[0] > 0 ? entry.client.size[0] : 1600,
            height: entry.client?.size?.[1] > 0 ? entry.client.size[1] : 900
        }))
        const maximumColumns = Math.max(1, Math.min(layoutCount, Math.floor(width / Theme.exposeCardMinWidth)))
        let best = {columns: 1, scale: -1, widthScale: 0}
        // Use one scale for all windows, preserving their relative sizes as well as aspect ratios.
        for (let columns = 1; columns <= maximumColumns; columns++) {
            const rows = Math.ceil(layoutCount / columns)
            let widthScale = Infinity
            let totalHeight = 0
            for (let index = 0; index < layoutCount; index += columns) {
                const row = sizes.slice(index, index + columns)
                widthScale = Math.min(widthScale,
                    Math.max(0, width - row.length * horizontalPadding - (row.length - 1) * spacing)
                        / row.reduce((sum, size) => sum + size.width, 0))
                totalHeight += Math.max(...row.map(size => size.height))
            }
            const heightScale = Math.max(0, height - rows * verticalPadding - (rows - 1) * spacing) / totalHeight
            const scale = Math.min(widthScale, heightScale)
            if (scale >= best.scale) best = {columns, scale, widthScale}
        }
        // Keep cards readable on small screens and scroll if they cannot all fit vertically.
        const minimumScale = layoutCount > 1 ? Theme.exposeCardMinWidth / Math.max(...sizes.map(size => size.width)) : 0
        const scale = Math.min(best.widthScale, Math.max(best.scale, minimumScale))
        const cards = []
        let y = 0
        for (let index = 0; index < layoutCount; index += best.columns) {
            const row = sizes.slice(index, index + best.columns)
            const rowHeight = Math.max(...row.map(size => size.height)) * scale + verticalPadding
            const rowWidth = row.reduce((sum, size) => sum + size.width * scale + horizontalPadding, 0)
                + (row.length - 1) * spacing
            let x = Math.max(0, (width - rowWidth) / 2)
            for (const size of row) {
                const cardWidth = size.width * scale + horizontalPadding
                cards.push({x, y, width: cardWidth, height: size.height * scale + verticalPadding,
                    row: Math.floor(index / best.columns)})
                x += cardWidth + spacing
            }
            y += rowHeight + spacing
        }
        const byId = {}
        layoutEntries.forEach((entry, index) => byId[entry.id] = cards[index])
        return {columns: best.columns, cards: arrangedEntries.map(entry => byId[entry.id] ?? null), byId,
            height: Math.max(0, y - spacing)}
    }
    function itemAtIndex(index) { return cards.itemAt(index) }
    function synchronizeWindows() {
        if (!modelReady) return
        const nextWorkspace = picker.exposeWorkspace
        if (displayedWorkspace !== nextWorkspace) {
            const previous = displayedWorkspace
            workspaceAnimation.stop()
            workspaceProgress = 1
            outgoingCards = []
            if (previous !== -1 && animationsEnabled && transitionProgress === 1 && !picker.exposeDragging) {
                const workspaces = picker.exposeWorkspaces
                const nextIndex = workspaces.findIndex(workspace => workspace.id === nextWorkspace)
                const previousIndex = workspaces.findIndex(workspace => workspace.id === previous)
                workspaceDirection = nextWorkspace === 0 ? 1 : previous === 0
                    ? (nextIndex < (workspaces.length - 1) / 2 ? -1 : 1)
                    : (nextIndex < previousIndex ? -1 : 1)
                const snapshot = []
                for (let index = 0; index < windowModel.count; index++) {
                    const card = cards.itemAt(index) as ExposeWindowCard
                    if (!card || card.dropAccepted) continue
                    const position = card.mapToItem(root, 0, 0)
                    snapshot.push({entry: card.entry, x: position.x, y: position.y,
                        width: card.width, height: card.height})
                }
                outgoingCards = snapshot
                workspaceProgress = 0
                workspaceAnimation.restart()
            }
            displayedWorkspace = nextWorkspace
        }
        arrangedEntries = entries
        const ids = new Set(entries.map(entry => entry.id))
        for (let index = windowModel.count - 1; index >= 0; index--) {
            if (!ids.has(windowModel.get(index).windowId)) windowModel.remove(index)
        }
        entries.forEach((entry, index) => {
            let previous = index
            while (previous < windowModel.count && windowModel.get(previous).windowId !== entry.id) previous++
            if (previous === windowModel.count) windowModel.insert(index, {windowId: entry.id, value: entry})
            else {
                if (previous !== index) windowModel.move(previous, index, 1)
                windowModel.setProperty(index, "value", entry)
            }
        })
    }
    onEntriesChanged: synchronizeWindows()
    Component.onCompleted: { modelReady = true; synchronizeWindows() }
    function finishWorkspaceTransition() {
        workspaceAnimation.stop()
        workspaceProgress = 1
        outgoingCards = []
    }
    onTransitionProgressChanged: if (transitionProgress !== 1) finishWorkspaceTransition()
    onAnimationsEnabledChanged: if (!animationsEnabled) finishWorkspaceTransition()
    NumberAnimation {
        id: workspaceAnimation
        target: root
        property: "workspaceProgress"
        from: 0
        to: 1
        duration: Theme.exposeRearrangeAnimationDuration
        easing.type: Easing.OutCubic
        onFinished: root.outgoingCards = []
    }
    // Preserve cards by window address so layout changes can animate existing previews.
    ListModel { id: windowModel; dynamicRoles: true }
    function moveVertical(direction) {
        const current = arrangement.cards[currentIndex]
        if (!current) return
        const center = current.x + current.width / 2
        let next = currentIndex
        let distance = Infinity
        arrangement.cards.forEach((card, index) => {
            if (!card) return
            if (card.row !== current.row + direction) return
            const delta = Math.abs(card.x + card.width / 2 - center)
            if (delta < distance) { distance = delta; next = index }
        })
        if (next !== currentIndex) picker.select(next, false)
    }
    function revealCurrent() {
        const card = arrangement.cards[currentIndex]
        if (!card || height <= 0) return
        const top = content.y + card.y
        const bottom = top + card.height
        const next = top < contentY ? top : bottom > contentY + height ? bottom - height : contentY
        contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height), next))
    }
    onCurrentIndexChanged: Qt.callLater(revealCurrent)
    onArrangementChanged: Qt.callLater(revealCurrent)
    contentWidth: width
    contentHeight: Math.max(height, arrangement.height)
    clip: transitionProgress === 1 || captureAddress === ""
    interactive: transitionProgress === 1 && !picker.exposeDragging
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Item {
        id: content
        width: root.width
        height: root.arrangement.height
        y: Math.max(0, (root.height - height) / 2)
        transform: Translate { x: root.workspaceDirection * root.width * (1 - root.workspaceProgress) }
        Behavior on y {
            enabled: root.animateLayout
            NumberAnimation { duration: Theme.exposeRearrangeAnimationDuration; easing.type: Easing.OutCubic }
        }
        Repeater {
            id: cards
            model: windowModel
            delegate: ExposeWindowCard {
                id: cardDelegate
                required property var value
                required property int index
                property bool geometryReady: false
                readonly property var geometry: root.arrangement.byId[value.id] ?? null
                property var slot: ({x: 0, y: 0, width: 0, height: 0})
                onGeometryChanged: if (geometry) slot = geometry
                Component.onCompleted: Qt.callLater(() => cardDelegate.geometryReady = true)
                objectName: "exposeWindow-" + value.id
                entry: value
                visible: root.transitionProgress === 1 || value.id === root.captureAddress
                    || ((geometry?.y ?? 0) + content.y - root.contentY < root.height
                        && (geometry?.y ?? 0) + content.y - root.contentY + height > 0)
                enabled: root.transitionProgress === 1
                x: slot.x
                y: slot.y
                width: slot.width
                height: slot.height
                Behavior on x {
                    enabled: cardDelegate.geometryReady && root.animateLayout
                    NumberAnimation { duration: Theme.exposeRearrangeAnimationDuration; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: cardDelegate.geometryReady && root.animateLayout
                    NumberAnimation { duration: Theme.exposeRearrangeAnimationDuration; easing.type: Easing.OutCubic }
                }
                Behavior on width {
                    enabled: cardDelegate.geometryReady && root.animateLayout
                    NumberAnimation { duration: Theme.exposeRearrangeAnimationDuration; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    enabled: cardDelegate.geometryReady && root.animateLayout
                    NumberAnimation { duration: Theme.exposeRearrangeAnimationDuration; easing.type: Easing.OutCubic }
                }
                current: root.currentIndex === index
                dragLayer: root.dragLayer
                onHovered: if (!root.picker.exposeDragging) root.picker.select(index, false)
                onActivated: { root.picker.select(index, false); root.picker.accept(false, false) }
                onDragStarted: {
                    root.dragAddress = entry.id
                    root.dragVacated = false
                    root.picker.exposeDragging = true
                }
                onDragMoved: (pointerX, pointerY) => {
                    const pointer = root.dragLayer.mapToItem(root, pointerX, pointerY)
                    root.dragVacated = pointer.y < 0
                }
                onDropCompleted: accepted => { if (!accepted) root.dragVacated = false }
                onDragFinished: {
                    root.dragAddress = ""
                    root.dragVacated = false
                    root.picker.exposeDragging = false
                }
            }
        }
    }
    Repeater {
        parent: root
        model: root.outgoingCards
        delegate: ExposeWindowCard {
            required property var modelData
            objectName: "exposeOutgoing-" + modelData.entry.id
            entry: modelData.entry
            dragLayer: root.dragLayer
            enabled: false
            x: modelData.x - root.workspaceDirection * root.width * root.workspaceProgress
            y: modelData.y
            width: modelData.width
            height: modelData.height
        }
    }
    QC.ScrollBar.vertical: UI.ScrollBar {}
}
