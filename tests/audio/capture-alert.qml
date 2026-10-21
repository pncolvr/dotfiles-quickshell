pragma ComponentBehavior: Bound
import QtQuick
import "../../src/services"
import "../../src/services/audio" as Audio
import "../../src/services/audio/CaptureAudio.mjs" as CaptureAudio
import "../../src/config"
import "../../src/i18n"
import "../launcher"

WorkerScope {
    id: root
    readonly property var settings: Config
    property var captures: []
    property var links: []
    property double desktopDeadline: 0
    readonly property var mic: ({properties:{"media.class":"Audio/Source","device.api":"alsa"},audio:{muted:false}})
    readonly property var sink: ({properties:{"media.class":"Audio/Sink"},audio:{muted:false}})
    readonly property var first: ({audio:{muted:false}})
    readonly property var second: ({audio:{muted:false}})
    function alert() { return AlertService.messages.find(message => message.id === "screenshare-status") }
    function route(sources) {
        captures = [first,second].slice(0,sources.length)
        links = sources.map((source,index) => ({source,target:captures[index],state:6}))
    }
    Audio.ScreenShareAlert {
        id: status
        duration: 100
        audioStatus: CaptureAudio.captureStatus(root.captures,root.links,6)
    }
    NativeFocusDriver {
        id: driver
        onFailed: message => { console.error("CAPTURE ALERT FAIL:",message); Qt.quit() }
        onCompleted: { console.log("PASS: screen capture alert only warns for desktop audio, expires, ignores microphone changes and dismisses on capture end"); Qt.quit() }
    }
    Component.onCompleted: {
        driver.waitFor("translations loaded", () => !!Translations.messages["screenshare.alert.audio.desktop"])
        driver.add("wait for complete discovery", () => {
            AlertService.post("unrelated","Unrelated alert","info")
            status.active = true
        })
        driver.add("incomplete registry does not announce capture", () => {
            driver.check(!root.alert(), "discovery guard")
            status.ready = true
        })
        driver.add("unknown audio stays silent", () => {
            driver.check(!root.alert(), "unknown audio does not warn")
            route([mic])
        })
        driver.add("microphone-only capture stays silent", () => {
            driver.check(!root.alert(), "microphone-only capture does not warn")
            route([sink])
        })
        driver.waitFor("desktop audio warning", () => root.alert()?.text === "Desktop audio capture detected", () => {
            driver.check(root.alert().severity === "warning" && root.alert().expiresAt > Date.now()
                && !root.alert().captureBlocking,"transient ordinary warning")
            root.desktopDeadline = root.alert().expiresAt
            route([mic,sink])
        })
        driver.add("microphone added to desktop capture does not renew warning", () => {
            driver.check(root.alert()?.expiresAt === root.desktopDeadline, "microphone change preserves expiration")
            driver.check(!root.alert().text.includes("Microphone"), "warning only mentions desktop audio")
            route([mic])
        })
        driver.waitFor("desktop capture ending dismisses warning even with microphone active", () => !root.alert(), () => route([]))
        driver.add("unknown audio remains silent after desktop capture", () => {
            driver.check(!root.alert(), "no unknown-audio warning")
            route([mic,sink])
        })
        driver.waitFor("desktop capture resuming posts a new warning", () => root.alert()?.text.includes("Desktop audio capture detected"), () => {
            driver.check(AlertService.messages.length === 2, "updates replace one alert and preserve unrelated alerts")
            root.settings.language = "pt"
        })
        driver.waitFor("translated live alert", () => root.alert()?.text === "Detetada captura de áudio do ambiente de trabalho", () => {
            status.ready = false
        })
        driver.add("transient discovery retains active warning", () => {
            driver.check(!!root.alert(), "registry resync does not flicker the warning")
            status.ready = true
        })
        driver.waitFor("alert expires while capture remains active", () => !root.alert(), () => {
            driver.check(status.active, "expiration does not stop capture")
            status.ready = false
            status.ready = true
        })
        driver.add("unchanged registry state does not repost expired alert", () => {
            driver.check(!root.alert(), "same status is not renewed")
            root.route([sink])
        })
        driver.add("microphone ending does not repost expired desktop warning", () => {
            driver.check(!root.alert(), "microphone changes cannot renew an expired warning")
            root.route([])
        })
        driver.add("desktop capture ended after expiration", () => {
            driver.check(!root.alert(), "unknown audio stays silent after expiration")
            root.route([sink])
        })
        driver.waitFor("new desktop capture posts another brief alert", () => !!root.alert(), () => {
            status.active = false
        })
        driver.waitFor("final capture dismisses only its alert", () => !root.alert(), () => {
            driver.check(AlertService.messages.length === 1 && AlertService.messages[0].id === "unrelated", "unrelated alert preserved")
            AlertService.dismiss("unrelated")
        })
        driver.running = true
    }
}
