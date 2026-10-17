import QtQuick
import "../../theme"
import ".." as UI

UI.Text {
    id: root
    property string hints: ""
    property string panelKey: ""
    property var availableActions: []
    property var actionOverrides: ({})
    readonly property string selectedHints: panelKey ? UI.Keybinds.panelHintText(panelKey, availableActions, actionOverrides)
        : [hints, closingHint].filter(Boolean).join(" · ")
    property string closingHint: ""
    centerVertical: false
    visible: text.length > 0
    height: text.length > 0 ? Math.max(Theme.controlHeight, Math.ceil(metrics.height
        + (text.split("\n").length - 1) * metrics.lineSpacing)) : 0
    verticalAlignment: Text.AlignVCenter
    font.pixelSize: Theme.fontSize - 1
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.NoWrap
    textFormat: Text.PlainText
    color: Theme.inactive
    // Measure with the rendered font; font changes must also reflow the hints.
    text: layoutHints(selectedHints, width, metrics.font)

    FontMetrics { id: metrics; font: root.font }

    function fits(value) {
        return Math.ceil(metrics.advanceWidth(value)) <= Math.floor(width)
    }

    function layoutHints(value, availableWidth, hintFont) {
        const groups = value.split(/\s*·\s*|\r?\n/).map(group => group.trim()).filter(group => group.length)
        if (availableWidth <= 0) return groups.join(" · ")
        const lines = []
        let line = ""
        for (const group of groups) {
            const combined = line ? line + " · " + group : group
            if (fits(combined)) {
                line = combined
            } else if (fits(group)) {
                if (line) lines.push(line)
                line = group
            } else {
                if (line) lines.push(line)
                // Only an oversized group's description may wrap. Keep its key
                // (including spaces, slashes and modifiers) as one whole token.
                const colon = group.indexOf(":")
                const split = colon >= 0 ? colon + 1 : group.indexOf(" ")
                const key = split >= 0 ? group.slice(0, split) : group
                const words = split >= 0 ? group.slice(split).trim().split(/\s+/).filter(word => word.length) : []
                line = key
                for (const word of words) {
                    if (fits(line + " " + word)) {
                        line += " " + word
                    } else {
                        lines.push(line)
                        line = word
                    }
                }
                lines.push(line)
                line = ""
            }
        }
        if (line) lines.push(line)
        return lines.join("\n")
    }
}
