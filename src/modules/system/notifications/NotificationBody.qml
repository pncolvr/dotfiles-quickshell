import "../../../i18n"
import QtQuick
import "../../../theme"
import "../../../ui" as UI

UI.Text {
    id: root
    property string body: ""
    property string emitterKey: ""
    property bool popup: false
    // Discord wraps message content in bidi isolates, including Markdown fences.
    readonly property string bodyText: body.replace(/[\u2066-\u2069]/g, "")
    // Teams flattens the n8n inbox table: headers first, then values in column order.
    readonly property var inboxReport: {
        if (emitterKey !== "desktop:teams-for-linux") return null
        const match = bodyText.match(/^((?:[^\n]*:\s*)?inbox(?:\.[a-z0-9._%+-]+)?@[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,})\s+Inbox\s+Junk\s+Error\s+(\d+)\s+(\d+)\s+(\d+)\s*$/i)
        return match ? { heading: match[1], inbox: match[2], junk: match[3], error: match[4] } : null
    }
    readonly property var twitchReport: parseTwitchReport(bodyText)
    readonly property var updateReport: parseUpdateReport(bodyText)
    readonly property var visibleTwitchReport: limitTwitchReport(twitchReport)
    readonly property int visibleUpdateCount: !updateReport ? 0 : popup && updateReport.length > 7 ? 6 : updateReport.length
    readonly property int hiddenUpdateCount: !updateReport ? 0 : updateReport.length - visibleUpdateCount
    readonly property bool formatted: !!inboxReport || !!twitchReport || !!updateReport || markdown
    function escapeHtml(value) {
        return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
    }
    function parseTwitchReport(value) {
        if (emitterKey !== "app:twitch") return null
        const lines = value.split("\n")
        if (lines.length < 3) return null
        const parseCells = line => {
            if (!line.startsWith("|") || !line.endsWith("|")) return null
            return line.slice(1, -1).split("|").map(cell => cell.trim())
        }
        const headers = parseCells(lines[0])
        const dividers = parseCells(lines[1])
        if (!headers || !headers.length || headers.length > 2 || !dividers || dividers.length !== headers.length
            || dividers.some(value => !/^:?-{3,}:?$/.test(value))) return null
        const rows = []
        for (const line of lines.slice(2)) {
            const cells = parseCells(line)
            if (!cells || cells.length !== headers.length) return null
            const values = []
            for (const cell of cells) {
                const match = cell.match(/^`([^`\n]+)`$/)
                if (cell && !match) return null
                values.push(match ? match[1] : "")
            }
            rows.push(values)
        }
        return rows.length ? {headers, rows} : null
    }
    function limitTwitchReport(report) {
        if (!report || !popup) return report
        const limit = report.headers.length > 1 ? 6 : 7
        if (report.rows.length <= limit) return report
        const shown = limit - 1
        const more = report.headers.map((_, column) => {
            const hidden = report.rows.slice(shown).filter(row => row[column]).length
            return hidden ? Translations.text("common.status.more", [], hidden) : ""
        })
        return {headers: report.headers, rows: [...report.rows.slice(0, shown), more]}
    }
    function parseUpdateReport(value) {
        if (emitterKey !== "app:updates") return null
        const rows = []
        for (const line of value.split("\n")) {
            const row = line.match(/^([^:\n]+):\s+(\S+)\s+->\s+(\S+)$/)
            if (!row) return null
            rows.push({name: row[1], oldVersion: row[2], newVersion: row[3]})
        }
        return rows.length ? rows : null
    }
    readonly property string inboxTable: {
        if (!inboxReport) return ""
        const border = `border: 1px solid ${Theme.notificationBorder};`
        const headers = [Translations.text("notifications.inbox.inbox"), Translations.text("notifications.inbox.junk"), Translations.text("common.states.error")].map(label =>
            `<th width="33%" style="${border} color: ${Theme.accent};">${label}</th>`).join("")
        const counts = [inboxReport.inbox, inboxReport.junk, inboxReport.error].map(count =>
            `<td align="center" style="${border}">${count}</td>`).join("")
        return `<p style="margin-top: 0; margin-bottom: 8px;">${escapeHtml(inboxReport.heading)}</p>`
            + `<table width="100%" border="1" cellspacing="0" cellpadding="6" style="border-collapse: collapse; border-color: ${Theme.notificationBorder};">`
            + `<tr>${headers}</tr><tr>${counts}</tr></table>`
    }
    readonly property string twitchTable: {
        if (!visibleTwitchReport) return ""
        const border = `border: 1px solid ${Theme.notificationBorder};`
        const width = Math.floor(100 / visibleTwitchReport.headers.length)
        const headers = visibleTwitchReport.headers.length > 1
            ? `<tr>${visibleTwitchReport.headers.map(header => `<th width="${width}%" align="left" style="${border} color: ${Theme.text};">${escapeHtml(header)}</th>`).join("")}</tr>` : ""
        const rows = visibleTwitchReport.rows.map(row => `<tr>${row.map(channel =>
            `<td width="${width}%" align="left" style="${border} color: ${Theme.text};">${escapeHtml(channel)}</td>`).join("")}</tr>`).join("")
        return `<table width="100%" border="1" cellspacing="0" cellpadding="3" style="border-collapse: collapse; border-color: ${Theme.notificationBorder}; color: ${Theme.text};">${headers}${rows}</table>`
    }
    readonly property string updateRows: {
        if (!updateReport) return ""
        const arrow = `<font face="${Theme.fontFamilyIcons}" color="${Theme.text}">${Theme.rightIcon}</font>`
        const rows = updateReport.slice(0, visibleUpdateCount).map(update =>
            `${escapeHtml(update.name)}&nbsp;&nbsp;${escapeHtml(update.oldVersion)}&nbsp;${arrow}&nbsp;${escapeHtml(update.newVersion)}`)
        if (hiddenUpdateCount) rows.push(escapeHtml(Translations.text("common.status.more", [], hiddenUpdateCount)))
        return `<font color="${Theme.text}">${rows.join("<br>")}</font>`
    }
    readonly property bool markdown: /```|~~~|`[^`\n]+`/.test(bodyText)
        || /\*\*[^*]+\*\*|__[^_]+__|~~[^~]+~~/.test(bodyText)
        || /(?:^|[\s(])[*_][^*_\n]+[*_](?=$|[\s.,!?;)])/.test(bodyText)
        || /\[[^\]]+\]\([^)]+\)/.test(bodyText)
        || /(?:^|\n) {0,3}(?:#{1,6} |[-*+] |\d+\. |> )/.test(bodyText)

    centerVertical: false
    visible: body.length > 0
    text: inboxReport ? inboxTable : twitchReport ? twitchTable : updateReport ? updateRows : markdown ? bodyText : body
    textFormat: inboxReport || twitchReport || updateReport ? Text.RichText : markdown ? Text.MarkdownText : Text.PlainText
    wrapMode: Text.Wrap
    // Formatted text ignores maximumLineCount and elide; bound it explicitly.
    height: popup && !twitchReport && !updateReport ? Math.min(implicitHeight, metrics.height * 8) : implicitHeight
    clip: popup && !twitchReport && !updateReport
    maximumLineCount: popup ? 8 : 2147483647
    elide: formatted ? Text.ElideNone : Text.ElideRight
    font.family: popup ? Theme.notificationFont : Theme.fontFamily
    font.bold: formatted ? false : Theme.fontBold
    font.weight: formatted ? Font.Normal : Theme.fontWeight
    font.styleName: formatted ? "" : Theme.fontStyle

    FontMetrics { id: metrics; font: root.font }
}
