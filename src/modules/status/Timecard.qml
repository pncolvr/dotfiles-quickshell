pragma Singleton

import QtQml

QtObject {
    id: root

    function seconds(duration: string): real {
        const parts = duration.split(":").map(Number)
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }

    function parse(text: string): var {
        const days = []
        let day = null
        const range = text.match(/^(\d{4}-\d{2}-\d{2}) – (\d{4}-\d{2}-\d{2})/)
        for (const line of text.split("\n")) {
            const date = line.match(/^(\d{4}-\d{2}-\d{2})$/)
            if (date) {
                day = {date: date[1], work: 0, personal: 0, blocks: []}
                days.push(day)
                continue
            }
            if (!day) continue
            const total = line.match(/^\s*(work|personal)\s+(\d+:\d{2}:\d{2})\s*$/)
            if (total) day[total[1]] = root.seconds(total[2])
            const block = line.match(/^\s*(\d{2}:\d{2}:\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(work|personal)\s+(\d+:\d{2}:\d{2})(?:\s+(ongoing))?\s*$/)
            if (block) day.blocks.push({start: block[1], end: block[2], category: block[3], duration: root.seconds(block[4]), ongoing: !!block[5]})
        }
        if (range) {
            const start = new Date(range[1] + "T12:00:00")
            const end = new Date(range[2] + "T12:00:00")
            while (start <= end) {
                const date = start.getFullYear() + "-" + String(start.getMonth() + 1).padStart(2, "0") + "-" + String(start.getDate()).padStart(2, "0")
                if (!days.some(entry => entry.date === date)) days.push({date: date, work: 0, personal: 0, blocks: []})
                start.setDate(start.getDate() + 1)
            }
            days.sort((left, right) => left.date.localeCompare(right.date))
        }
        return {
            days: days,
            work: days.reduce((total, entry) => total + entry.work, 0),
            personal: days.reduce((total, entry) => total + entry.personal, 0),
            range: range ? range[1] + " – " + range[2] : ""
        }
    }

    function duration(value: real): string {
        const hours = Math.floor(value / 3600)
        const minutes = Math.floor(value % 3600 / 60)
        if (hours) return hours + "h " + minutes + "m"
        return minutes ? minutes + "m" : value ? value + "s" : "0m"
    }
}
