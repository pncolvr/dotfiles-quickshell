import QtQml
import Quickshell
import "../../src/services"
import "../../src/i18n"

Scope {
    id: root
    property int completed: 0
    property bool failed: false
    function check(value, message) {
        if (value) return
        failed = true
        console.error("MUTE SERVICE FAIL: " + message)
    }
    function next() {
        check(!AudioService.muteBusy, "worker completed before next request")
        if (completed === 1) {
            check(AudioService.muteError === "", "successful mute has no error")
            AudioService.toggleMute()
        } else if (completed === 2) {
            check(AudioService.muteError === Translations.text("audio.errors.discordSync"), "Discord warning is translated")
            AudioService.toggleMicMute()
        } else if (completed === 3) {
            check(AudioService.muteError === Translations.text("audio.errors.changeMute"), "system failure is translated")
            AudioService.toggleMicMute()
            check(AudioService.muteError === "", "next request clears previous error")
        } else {
            check(AudioService.muteError === "", "service recovers after failure")
            if (!failed) console.log("PASS: AudioService mute dispatch, overlap guard, translated warnings, failures and recovery")
            Qt.quit()
        }
    }
    Connections {
        target: AudioService
        function onMuteBusyChanged() {
            if (AudioService.muteBusy) return
            root.completed++
            Qt.callLater(root.next)
        }
    }
    Component.onCompleted: {
        AudioService.toggleMicMute()
        check(AudioService.muteBusy, "request starts the owned worker")
        AudioService.toggleMute()
        AudioService.toggleMicMute()
    }
}
