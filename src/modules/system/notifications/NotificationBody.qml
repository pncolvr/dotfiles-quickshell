import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI

UI.Text {
    id: root
    property string body: ""
    property bool popup: false
    // Discord wraps message content in bidi isolates, including Markdown fences.
    readonly property string bodyText: body.replace(/[\u2066-\u2069]/g, "")
    readonly property bool markdown: /```|~~~|`[^`\n]+`/.test(bodyText)
        || /\*\*[^*]+\*\*|__[^_]+__|~~[^~]+~~/.test(bodyText)
        || /(?:^|[\s(])[*_][^*_\n]+[*_](?=$|[\s.,!?;)])/.test(bodyText)
        || /\[[^\]]+\]\([^)]+\)/.test(bodyText)
        || /(?:^|\n) {0,3}(?:#{1,6} |[-*+] |\d+\. |> )/.test(bodyText)

    centerVertical: false
    visible: body.length > 0
    text: markdown ? bodyText : body
    textFormat: markdown ? Text.MarkdownText : Text.PlainText
    wrapMode: Text.Wrap
    // Markdown text ignores maximumLineCount and elide; bound it explicitly.
    height: popup ? Math.min(implicitHeight, metrics.height * 8) : implicitHeight
    clip: popup
    maximumLineCount: popup ? 8 : 2147483647
    elide: markdown ? Text.ElideNone : Text.ElideRight
    font.family: popup ? Theme.notificationFont : Theme.fontFamily
    font.bold: markdown ? false : Theme.fontBold
    font.weight: markdown ? Font.Normal : Theme.fontWeight
    font.styleName: markdown ? "" : Theme.fontStyle

    FontMetrics { id: metrics; font: root.font }
}
