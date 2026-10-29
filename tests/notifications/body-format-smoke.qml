import QtQuick
import Quickshell
import "../../src/i18n"
import "../../src/theme"
import "../../src/modules/system/notifications" as Notifications

Scope {
    id: root
    property bool failed: false
    function verify(value, message = "assertion") { if (!value) { failed = true; console.error("BODY FORMAT FAIL:", message) } }
    function compare(actual, expected) {
        if (actual !== expected) { failed = true; console.error("BODY FORMAT FAIL:", actual, "expected", expected) }
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 440
        implicitHeight: 200
        color: Theme.notificationBackground
        Rectangle {
            id: preview
            anchors.fill: parent
            color: Theme.notificationBackground
            Notifications.NotificationBody { id: content; x: 20; y: 20; width: 400; popup: true }
        }
    }
    Timer {
        interval: 100
        running: true
        onTriggered: {
            if (!Translations.availableLanguages.includes("en")) { restart(); return }
            root.init(); root.test_receivedTeamsReport()
            root.init(); root.test_columnOrderAndWhitespace()
            root.init(); root.test_escapeHeading()
            for (const data of root.test_incompleteReportsStayPlain_data()) {
                root.init(); root.test_incompleteReportsStayPlain(data)
            }
            root.init(); root.test_reportScope()
            root.init(); root.test_twitchRows()
            root.init(); root.test_twitchRowsScope()
            root.init(); root.test_updateRows()
            root.init(); root.test_updateRowsScope()
            root.init(); root.test_discordMarkdownUnchanged()
            root.init(); root.test_discordImageUrl()
            content.emitterKey = "desktop:teams-for-linux"
            content.body = "Team Admin: inbox@example.com Inbox\nJunk\nError 0\n1\n0"
            content.popup = true
            finish.start()
        }
    }
    Timer {
        id: finish
        interval: 100
        onTriggered: {
            root.verify(content.height === content.implicitHeight && content.contentHeight === content.height && content.lineCount >= 3 && !content.truncated)
            console.log(root.failed ? "BODY FORMAT FAIL: notification formatting" : "PASS: Teams table, Twitch and Updates rows, emitter scope, escaping, plain text fallback and Discord Markdown")
            if (Quickshell.env("NOTIFICATION_BODY_SCREENSHOT")) {
                preview.grabToImage(result => { result.saveToFile(Quickshell.env("NOTIFICATION_BODY_SCREENSHOT")); Qt.quit() })
            } else Qt.quit()
        }
    }

    function init() { content.body = ""; content.popup = false; content.emitterKey = "desktop:teams-for-linux" }

    function test_receivedTeamsReport() {
        const received = "Team Admin: inbox@example.com Inbox\nJunk\nError 0\n1\n0"
        content.body = received
        compare(content.body, received)
        compare(content.inboxReport.heading, "Team Admin: inbox@example.com")
        compare(content.inboxReport.inbox, "0")
        compare(content.inboxReport.junk, "1")
        compare(content.inboxReport.error, "0")
        compare(content.textFormat, Text.RichText)
        verify(content.text.includes("<th"))
        verify(content.implicitHeight > 0)
        content.popup = true
        compare(content.textFormat, Text.RichText)
        verify(content.height <= content.implicitHeight)
    }

    function test_columnOrderAndWhitespace() {
        content.body = "Team Admin: inbox@example.com\nInbox\tJunk\nError\n23\n4\n17"
        compare(content.inboxReport.inbox, "23")
        compare(content.inboxReport.junk, "4")
        compare(content.inboxReport.error, "17")
        verify(content.text.indexOf(">23</td>") < content.text.indexOf(">4</td>"))
        verify(content.text.indexOf(">4</td>") < content.text.indexOf(">17</td>"))
    }

    function test_escapeHeading() {
        content.body = 'Team <Admin & "Ops">: inbox@example.com Inbox Junk Error 1 2 3'
        verify(!content.text.includes("<Admin"))
        verify(content.text.includes("Team &lt;Admin &amp; &quot;Ops&quot;&gt;:"))
    }

    function test_incompleteReportsStayPlain_data() {
        return [
            {tag: "missing count", body: "inbox@example.com Inbox Junk Error 1 2"},
            {tag: "extra text", body: "inbox@example.com Inbox Junk Error 1 2 3 and more"},
            {tag: "different order", body: "inbox@example.com Junk Inbox Error 1 2 3"},
            {tag: "missing mailbox", body: "Inbox Junk Error 1 2 3"},
            {tag: "ordinary text", body: "Inbox has 3 unread messages\nContact inbox@example.com"}
        ]
    }
    function test_incompleteReportsStayPlain(data) {
        content.body = data.body
        compare(content.inboxReport, null)
        compare(content.textFormat, Text.PlainText)
        compare(content.text, data.body)
    }

    function test_reportScope() {
        const received = "Team Admin: inbox@example.com Inbox\nJunk\nError 0\n1\n0"
        content.body = received
        for (const emitter of ["", "desktop:discord", "app:other", "desktop:other-teams-app"]) {
            content.emitterKey = emitter
            compare(content.inboxReport, null)
            compare(content.textFormat, Text.PlainText)
            compare(content.text, received)
        }
        content.emitterKey = "desktop:teams-for-linux"
        compare(content.textFormat, Text.RichText)
        for (const mailbox of ["inbox.operations@example.org", "inbox@sub.example.net"]) {
            content.body = received.replace("inbox@example.com", mailbox)
            compare(content.textFormat, Text.RichText)
            compare(content.inboxReport.inbox, "0")
        }
        for (const mailbox of ["report@example.com", "other.inbox@example.com", "inbox@example", "inbox@", "inbox@example.com extra"]) {
            content.body = received.replace("inbox@example.com", mailbox)
            compare(content.inboxReport, null)
            compare(content.textFormat, Text.PlainText)
            compare(content.text, content.body)
        }
    }

    function test_discordMarkdownUnchanged() {
        content.emitterKey = "desktop:discord"
        content.body = "inbox@example.com\n\u2068```\nJunk:1\nError:0\nInbox:0\n```\u2069"
        compare(content.inboxReport, null)
        compare(content.textFormat, Text.MarkdownText)
        verify(!content.text.includes("\u2068"))
        verify(content.text.includes("Junk:1"))
    }

    function test_discordImageUrl() {
        const image = "https://instagram.example.test/media/story.heic?stp=dst-jpg_e35"
        content.emitterKey = "desktop:discord"
        content.body = image
        compare(content.remoteImageUrl, image)
        content.body = "https://example.test/page?id=photo.jpg"
        compare(content.remoteImageUrl, "")
        content.body = "image: " + image
        compare(content.remoteImageUrl, "")
        content.body = image
        content.emitterKey = "app:other"
        compare(content.remoteImageUrl, "")
    }

    function test_twitchRows() {
        content.emitterKey = "app:twitch"
        content.body = "online\talice\nonline\tbob\noffline\tcharlie"
        compare(content.twitchReport.length, 3)
        compare(content.twitchReport[0].login, "alice")
        compare(content.twitchReport[0].online, true)
        compare(content.twitchReport[2].online, false)
        compare(content.textFormat, Text.RichText)
        verify(content.text.includes(`<b><font color="${Theme.ok}">alice</font></b>`)
            && content.text.includes(`<b><font color="${Theme.urgent}">charlie</font></b>`),
            "Twitch logins use bold online and offline colors")
        verify(!content.text.includes(Theme.twitchIcon) && !content.text.includes("<table")
            && !content.text.includes("Live") && !content.text.includes("Offline"),
            "Twitch rows contain only colored logins without icons or headings")

        content.popup = true
        content.body = Array.from({length: 10}, (_, index) => `${index < 7 ? "online" : "offline"}\tstreamer_${index}`).join("\n")
        compare(content.visibleTwitchCount, 6)
        compare(content.hiddenTwitchCount, 4)
        verify(content.text.includes(Translations.text("common.status.more", [], 4)), "Twitch overflow count")
        verify(!content.text.includes("streamer_6"), "Twitch hidden rows")
    }

    function test_twitchRowsScope() {
        const body = "online\talice"
        content.body = body
        for (const emitter of ["", "app:other", "desktop:twitch"]) {
            content.emitterKey = emitter
            compare(content.twitchReport, null)
            compare(content.textFormat, Text.PlainText)
        }
        content.emitterKey = "app:twitch"
        content.body = "| malformed |"
        compare(content.twitchReport, null)
        compare(content.textFormat, Text.PlainText)
    }

    function test_updateRows() {
        content.emitterKey = "app:updates"
        content.body = "linux: 6.17.1 -> 6.17.2\nfirefox: 145.0 -> 146.0"
        compare(content.updateReport.length, 2)
        compare(content.updateReport[0].name, "linux")
        compare(content.updateReport[1].newVersion, "146.0")
        compare(content.textFormat, Text.RichText)
        verify(content.text.includes(Theme.fontFamilyIcons) && content.text.includes(Theme.rightIcon), "Updates Font Awesome arrow")
        verify(!content.text.includes("<li") && !content.text.includes("•"), "Updates has no bullets")
        verify(content.text.includes(`color="${Theme.text}"`), "Updates uniform color")

        content.popup = true
        content.body = Array.from({length: 10}, (_, index) => `package-${index}: 1 -> 2`).join("\n")
        compare(content.visibleUpdateCount, 6)
        compare(content.hiddenUpdateCount, 4)
        verify(content.text.includes(Translations.text("common.status.more", [], 4)), "Updates overflow count: " + content.text)
        verify(!content.text.includes("package-6"), "Updates hidden rows: " + content.text)
    }

    function test_updateRowsScope() {
        const body = "linux: 6.17.1 -> 6.17.2"
        content.body = body
        for (const emitter of ["", "app:other", "desktop:updates"]) {
            content.emitterKey = emitter
            compare(content.updateReport, null)
            compare(content.textFormat, Text.PlainText)
            compare(content.text, body)
        }
        content.emitterKey = "app:updates"
        content.body = "malformed update"
        compare(content.updateReport, null)
        compare(content.textFormat, Text.PlainText)
    }
}
