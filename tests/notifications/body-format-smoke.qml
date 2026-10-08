import QtQuick
import Quickshell
import "../../src/theme"
import "../../src/modules/system/notifications" as Notifications

Scope {
    id: root
    property bool failed: false
    function verify(value) { if (!value) { failed = true; console.error("BODY FORMAT FAIL: assertion") } }
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
            root.init(); root.test_receivedTeamsReport()
            root.init(); root.test_columnOrderAndWhitespace()
            root.init(); root.test_escapeHeading()
            for (const data of root.test_incompleteReportsStayPlain_data()) {
                root.init(); root.test_incompleteReportsStayPlain(data)
            }
            root.init(); root.test_reportScope()
            root.init(); root.test_discordMarkdownUnchanged()
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
            console.log(root.failed ? "BODY FORMAT FAIL: inbox table" : "PASS: Teams/mailbox scope, inbox table, column order, escaping, plain text fallback and Discord Markdown")
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
}
