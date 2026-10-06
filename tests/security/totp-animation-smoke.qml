pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../src/modules/system/totp"

Scope {
    id: root
    property int step: 0
    property int ticks: 0
    property int progressUpdates: 0
    property int idleUpdates: 0

    function check(condition, message) {
        if (condition) return true
        console.error("TOTP ANIMATION FAIL: " + message)
        ticker.stop()
        Qt.quit()
        return false
    }
    function renderedCode() {
        let result = ""
        function find(item, name) {
            if (item.objectName === name) return item
            for (const child of item.children ?? []) {
                const found = find(child, name)
                if (found) return found
            }
            return null
        }
        for (let index = 0; index < digits.code.length; index++)
            result += find(digits, "totpDigit_" + index)?.text ?? ""
        return result
    }

    FloatingWindow {
        visible: true
        implicitWidth: 200
        implicitHeight: 80
        TotpCode { id: digits; anchors.centerIn: parent; code: "123456" }
    }
    Connections {
        target: digits
        function onProgressChanged() { root.progressUpdates++ }
    }
    Timer {
        id: ticker
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (!root.check(++root.ticks < 40, "animation timed out")) return
            switch (root.step) {
            case 0:
                if (!root.check(!digits.spinning && root.renderedCode() === "123456", "initial code is immediately readable")) return
                digits.code = "765432"
                if (!root.check(digits.spinning, "changed code starts the reels")) return
                root.step++
                break
            case 1:
                if (!root.check(digits.progress > 0 && digits.progress < 1, "reels move between frames")) return
                digits.code = "345678"
                if (!root.check(digits.spinning && digits.progress === 0, "another code change restarts the short transition")) return
                root.step++
                break
            case 2:
                if (digits.spinning) return
                if (!root.check(root.renderedCode() === "345678", "rapid replacement settles on the current code")) return
                digits.code = "345678"
                if (!root.check(!digits.spinning, "unchanged code stays idle")) return
                digits.code = "01234567"
                if (!root.check(!digits.spinning, "digit-count changes display immediately")) return
                root.step++
                break
            case 3:
                if (!root.check(root.renderedCode() === "01234567", "eight digits and leading zero are preserved")) return
                digits.code = "87654321"
                if (!root.check(digits.spinning, "eight-digit code also rolls")) return
                digits.animationsEnabled = false
                if (!root.check(!digits.spinning && root.renderedCode() === "87654321", "disabling animation settles immediately")) return
                digits.animationsEnabled = true
                digits.code = "23456789"
                digits.visible = false
                if (!root.check(!digits.spinning, "hiding the code stops animation")) return
                digits.code = "34567890"
                if (!root.check(!digits.spinning, "hidden code changes do not animate")) return
                digits.visible = true
                root.step++
                break
            case 4:
                if (!root.check(root.renderedCode() === "34567890" && !digits.spinning, "showing the code uses its latest value without replaying")) return
                root.idleUpdates = root.progressUpdates
                root.step++
                break
            case 5:
                if (!root.check(root.progressUpdates === root.idleUpdates, "idle code has no animation updates")) return
                console.log("PASS: TOTP rolling digits, rapid changes, eight digits, visibility and idle animation")
                ticker.stop()
                Qt.quit()
                break
            }
        }
    }
}
