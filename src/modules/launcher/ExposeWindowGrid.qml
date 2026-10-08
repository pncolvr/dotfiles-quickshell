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
    readonly property int count: picker.filteredItems.length
    readonly property int currentIndex: picker.currentIndex
    readonly property int columns: arrangement.columns
    readonly property var arrangement: {
        if (!count || width <= 0 || height <= 0) return {columns: 1, cards: [], height: 0}
        const spacing = Theme.exposeSpacing
        const horizontalPadding = Theme.controlSpacing * 2
        const verticalPadding = Theme.controlHeight + Theme.controlSpacing + 1
        const sizes = picker.filteredItems.map(entry => ({
            width: entry.client?.size?.[0] > 0 ? entry.client.size[0] : 1600,
            height: entry.client?.size?.[1] > 0 ? entry.client.size[1] : 900
        }))
        const maximumColumns = Math.max(1, Math.min(count, Math.floor(width / Theme.exposeCardMinWidth)))
        let best = {columns: 1, scale: -1, widthScale: 0}
        // Use one scale for all windows, preserving their relative sizes as well as aspect ratios.
        for (let columns = 1; columns <= maximumColumns; columns++) {
            const rows = Math.ceil(count / columns)
            let widthScale = Infinity
            let totalHeight = 0
            for (let index = 0; index < count; index += columns) {
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
        const minimumScale = count > 1 ? Theme.exposeCardMinWidth / Math.max(...sizes.map(size => size.width)) : 0
        const scale = Math.min(best.widthScale, Math.max(best.scale, minimumScale))
        const cards = []
        let y = 0
        for (let index = 0; index < count; index += best.columns) {
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
        return {columns: best.columns, cards, height: Math.max(0, y - spacing)}
    }
    function itemAtIndex(index) { return cards.itemAt(index) }
    function moveVertical(direction) {
        const current = arrangement.cards[currentIndex]
        if (!current) return
        const center = current.x + current.width / 2
        let next = currentIndex
        let distance = Infinity
        arrangement.cards.forEach((card, index) => {
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
        Repeater {
            id: cards
            model: root.picker.filteredItems
            delegate: ExposeWindowCard {
                required property var modelData
                required property int index
                readonly property var geometry: root.arrangement.cards[index]
                objectName: "exposeWindow-" + modelData.id
                entry: modelData
                visible: root.transitionProgress === 1 || modelData.id === root.captureAddress
                    || ((geometry?.y ?? 0) + content.y - root.contentY < root.height
                        && (geometry?.y ?? 0) + content.y - root.contentY + height > 0)
                enabled: root.transitionProgress === 1
                x: geometry?.x ?? 0
                y: geometry?.y ?? 0
                width: geometry?.width ?? 0
                height: geometry?.height ?? 0
                current: root.currentIndex === index
                dragLayer: root.dragLayer
                onHovered: if (!root.picker.exposeDragging) root.picker.select(index, false)
                onActivated: { root.picker.select(index, false); root.picker.accept(false, false) }
                onDragStarted: root.picker.exposeDragging = true
                onDragFinished: root.picker.exposeDragging = false
            }
        }
    }
    QC.ScrollBar.vertical: UI.ScrollBar {}
}
