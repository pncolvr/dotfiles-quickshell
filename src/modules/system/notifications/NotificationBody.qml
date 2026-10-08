import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI

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
    readonly property bool formatted: !!inboxReport || markdown
    function escapeHtml(value) {
        return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
    }
    readonly property string inboxTable: {
        if (!inboxReport) return ""
        const border = `border: 1px solid ${Theme.notificationBorder};`
        const headers = ["Inbox", "Junk", "Error"].map(label =>
            `<th width="33%" style="${border} color: ${Theme.accent};">${label}</th>`).join("")
        const counts = [inboxReport.inbox, inboxReport.junk, inboxReport.error].map(count =>
            `<td align="center" style="${border}">${count}</td>`).join("")
        return `<p style="margin-top: 0; margin-bottom: 8px;">${escapeHtml(inboxReport.heading)}</p>`
            + `<table width="100%" border="1" cellspacing="0" cellpadding="6" style="border-collapse: collapse; border-color: ${Theme.notificationBorder};">`
            + `<tr>${headers}</tr><tr>${counts}</tr></table>`
    }
    readonly property bool markdown: /```|~~~|`[^`\n]+`/.test(bodyText)
        || /\*\*[^*]+\*\*|__[^_]+__|~~[^~]+~~/.test(bodyText)
        || /(?:^|[\s(])[*_][^*_\n]+[*_](?=$|[\s.,!?;)])/.test(bodyText)
        || /\[[^\]]+\]\([^)]+\)/.test(bodyText)
        || /(?:^|\n) {0,3}(?:#{1,6} |[-*+] |\d+\. |> )/.test(bodyText)

    centerVertical: false
    visible: body.length > 0
    text: inboxReport ? inboxTable : markdown ? bodyText : body
    textFormat: inboxReport ? Text.RichText : markdown ? Text.MarkdownText : Text.PlainText
    wrapMode: Text.Wrap
    // Formatted text ignores maximumLineCount and elide; bound it explicitly.
    height: popup ? Math.min(implicitHeight, metrics.height * 8) : implicitHeight
    clip: popup
    maximumLineCount: popup ? 8 : 2147483647
    elide: formatted ? Text.ElideNone : Text.ElideRight
    font.family: popup ? Theme.notificationFont : Theme.fontFamily
    font.bold: formatted ? false : Theme.fontBold
    font.weight: formatted ? Font.Normal : Theme.fontWeight
    font.styleName: formatted ? "" : Theme.fontStyle

    FontMetrics { id: metrics; font: root.font }
}
