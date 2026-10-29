import "../../../i18n"
import QtQuick
import "../../../theme"
import "../../../ui" as UI

UI.Text {
    id: root
    property string body: ""
    property string emitterKey: ""
    property bool popup: false
    property bool hideRemoteImageUrl: false
    // Discord wraps message content in bidi isolates, including Markdown fences.
    readonly property string bodyText: body.replace(/[\u2066-\u2069]/g, "")
    readonly property string remoteImageUrl: imageUrl(bodyText)
    // Teams flattens the n8n inbox table: headers first, then values in column order.
    readonly property var inboxReport: {
        if (emitterKey !== "desktop:teams-for-linux") return null
        const match = bodyText.match(/^((?:[^\n]*:\s*)?inbox(?:\.[a-z0-9._%+-]+)?@[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,})\s+Inbox\s+Junk\s+Error\s+(\d+)\s+(\d+)\s+(\d+)\s*$/i)
        return match ? { heading: match[1], inbox: match[2], junk: match[3], error: match[4] } : null
    }
    readonly property var twitchReport: parseTwitchReport(bodyText)
    readonly property var updateReport: parseUpdateReport(bodyText)
    readonly property int visibleTwitchCount: !twitchReport ? 0 : popup && twitchReport.length > 7 ? 6 : twitchReport.length
    readonly property int hiddenTwitchCount: !twitchReport ? 0 : twitchReport.length - visibleTwitchCount
    readonly property int visibleUpdateCount: !updateReport ? 0 : popup && updateReport.length > 7 ? 6 : updateReport.length
    readonly property int hiddenUpdateCount: !updateReport ? 0 : updateReport.length - visibleUpdateCount
    readonly property bool formatted: !!inboxReport || !!twitchReport || !!updateReport || markdown
    function escapeHtml(value) {
        return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
    }
    function imageUrl(value) {
        const url = value.trim()
        if (!/^https:\/\/[^\s]+$/i.test(url)) return ""
        const path = url.split(/[?#]/, 1)[0]
        return /\.(?:avif|bmp|gif|heic|heif|jpe?g|png|webp)$/i.test(path) ? url : ""
    }
    function parseTwitchReport(value) {
        if (emitterKey !== "app:twitch") return null
        const rows = []
        for (const line of value.split("\n")) {
            const match = line.match(/^(online|offline)\t([a-z0-9_]{1,25})$/)
            if (!match) return null
            rows.push({online: match[1] === "online", login: match[2]})
        }
        return rows.length ? rows : null
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
    readonly property string twitchRows: {
        if (!twitchReport) return ""
        const rows = twitchReport.slice(0, visibleTwitchCount).map(stream => {
            const color = stream.online ? Theme.ok : Theme.urgent
            return `<b><font color="${color}">${escapeHtml(stream.login)}</font></b>`
        })
        if (hiddenTwitchCount) rows.push(`<font color="${Theme.text}">${escapeHtml(Translations.text("common.status.more", [], hiddenTwitchCount))}</font>`)
        return rows.join("<br>")
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
    visible: body.length > 0 && !(hideRemoteImageUrl && remoteImageUrl)
    text: inboxReport ? inboxTable : twitchReport ? twitchRows : updateReport ? updateRows : markdown ? bodyText : body
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
