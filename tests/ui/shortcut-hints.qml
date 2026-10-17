import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/ui" as UI
import "../../src/theme"

Scope {
    id: root
    property bool failed: false
    property int step: 0
    property int sample: 0
    readonly property var samples: JSON.parse(sampleFile.text() || "[]")
    FileView { id: sampleFile; path: Qt.resolvedUrl("samples.json"); blockLoading: true }
    readonly property var widths: [320, 560, 780, 1600]
    readonly property var sizes: [10, 16]
    function check(ok, message) {
        if (!ok) { failed = true; console.error("HINTS FAIL:", message) }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1700
        implicitHeight: 800
        UI.ShortcutHints { id: hints; width: 560 }
    }
    FontMetrics { id: metrics; font: hints.font }
    Timer {
        interval: 2
        running: root.samples.length > 0
        repeat: true
        onTriggered: {
            if (root.step >= root.widths.length * root.sizes.length) {
                // Wide hints collapse to one line, including old forced breaks.
                hints.width = 1600
                hints.font.pixelSize = 10
                hints.hints = "Enter: Open\nEsc: Close · Ctrl+E: Edit"
                root.check(hints.lineCount === 1, "prefer one line when it fits")
                root.check(hints.text === "Enter: Open · Esc: Close · Ctrl+E: Edit", "normalize old forced breaks")
                hints.width = 150
                hints.hints = "Ctrl + Shift + I: A long description that needs several lines of space"
                root.check(hints.text.split("\n")[0].startsWith("Ctrl + Shift + I:"), "keep a spaced keybind intact")
                root.check(hints.text.split("\n").length > 1, "oversized descriptions wrap")
                root.check(hints.horizontalAlignment === Text.AlignHCenter && hints.verticalAlignment === Text.AlignVCenter,
                    "hints stay centered in their final row")
                root.check(hints.height === Math.max(Theme.controlHeight, hints.implicitHeight), "height fits all lines without an extra row")
                hints.width = 1600
                hints.hints = "Enter/Click: Open · Ctrl+E: Edit"
                hints.closingHint = "Esc: Close"
                root.check(hints.text === "Enter/Click: Open · Ctrl+E: Edit · Esc: Close", "closing action remains last after feature actions")
                hints.hints += " · Ctrl+Shift+I: Preview"
                root.check(hints.text.endsWith("Preview · Esc: Close"), "dynamic actions precede closing")
                hints.closingHint = ""
                hints.hints = ""
                root.check(hints.text === "" && hints.height === 0 && !hints.visible, "empty hints collapse their row")
                console.log("PASS: bilingual shortcut groups, no stranded dots, responsive widths/fonts and centered hint rows")
                stop()
                Qt.quit()
                return
            }
            hints.width = root.widths[root.step % root.widths.length]
            hints.font.pixelSize = root.sizes[Math.floor(root.step / root.widths.length)]
            hints.hints = root.samples[root.sample]
            const groups = hints.hints.split(/\s*·\s*|\r?\n/).map(value => value.trim()).filter(value => value.length)
            const rendered = hints.text.split("\n")
            if (Math.ceil(metrics.advanceWidth(groups.join(" · "))) <= hints.width) {
                root.check(rendered.length === 1, "keep a fitting hint set on one line")
            }
            const context = "sample " + root.sample + ", width " + hints.width + ", font " + hints.font.pixelSize
            for (const line of rendered) {
                root.check(!/^\s*·|·\s*$/.test(line), "stranded separator: " + context)
            }
            for (const group of groups) {
                if (Math.ceil(metrics.advanceWidth(group)) <= hints.width) {
                    root.check(hints.text.includes(group), "split a fitting shortcut/action: " + group + ", " + context)
                }
            }
            const normalize = value => value.replace(/[·\n]/g, " ").replace(/\s+/g, " ").trim()
            root.check(normalize(hints.text) === normalize(hints.hints), "lost or changed hint text: " + context)
            root.check(hints.contentWidth <= hints.width + 1, "hint exceeds panel: " + context)
            root.sample++
            if (root.sample === root.samples.length) { root.sample = 0; root.step++ }
        }
    }
}
