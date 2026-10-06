pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/modules/system/audio"
import "../../src/services"
import "../../src/theme"
import "../../src/config"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    property bool screenshotTaken: false
    function check(condition, message) {
        if (condition) return
        failed = true
        console.error("AUDIO SMOKE FAIL: " + message)
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    function appRow(panel, key) {
        const apps = find(panel, "audioProcesses")
        for (let index = 0; index < apps.count; index++) {
            const row = apps.itemAt(index)
            if (row.app.key === key) return row
        }
        return null
    }
    function selectTab(panel, index) {
        const tabs = find(panel, "audioTabs") as QC.TabBar
        wheelEvents.mouseClick(tabs.itemAt(index))
        const deviceContents = find(panel, "audioDevices").parent as Column
        const appContents = find(panel, "audioProcesses").parent as Column
        deviceContents.forceLayout()
        appContents.forceLayout()
        panel.forceLayout()
        check(tabs.currentIndex === index, "audio tab responds to clicks")
        check(find(panel, "audioDeviceList").visible === (index === 1)
            && find(panel, "audioAppList").visible === (index === 0), "only the selected audio list is visible")
    }
    component AudioState: QtObject {
        property real volume: 0
        property bool muted: false
    }
    component AppStream: QtObject {
        required property string appName
        required property string processId
        required property string serial
        property bool ready: true
        property var properties: ({"application.name": appName, "application.process.id": processId, "object.serial": serial})
        property AudioState audio: AudioState {}
    }
    AppStream { id: browser; appName: "Browser"; processId: "10"; serial: "101" }
    AppStream { id: secondBrowser; appName: "Browser"; processId: "10"; serial: "102" }
    AppStream { id: player; appName: "Player"; processId: "11"; serial: "103" }
    AppStream { id: recorder; appName: "Recorder"; processId: "20"; serial: "201" }
    AppStream { id: call; appName: "Call"; processId: "21"; serial: "202" }
    QtObject {
        id: output
        property string name: "output"
        property string description: "Headphones"
        property bool ready: true
        property AudioState audio: AudioState { volume: 0.4 }
    }
    QtObject {
        id: input
        property string name: "input"
        property string description: "Headset microphone"
        property bool ready: true
        property AudioState audio: AudioState { volume: 0.65 }
    }
    QtObject {
        id: secondOutput
        property string name: "second-output"
        property string description: "Speakers"
        property bool ready: true
        property AudioState audio: AudioState { volume: 0.2 }
    }
    QtObject {
        id: secondInput
        property string name: "second-input"
        property string description: "Webcam microphone"
        property bool ready: true
        property AudioState audio: AudioState { volume: 0.5 }
    }
    QtObject {
        id: backend
        property var outputs: [output, secondOutput]
        property var inputs: [input, secondInput]
        readonly property var outputDevices: outputs
        readonly property var inputDevices: inputs
        property var defaultOutput: output
        property var defaultInput: input
        property var currentOutput: output
        property var currentInput: input
        property var recordingNodes: [recorder, call]
        property var playbackNodes: [browser, secondBrowser, player]
        property var recordingLinks: [{source: input, target: recorder}, {source: input, target: call}]
        property var playbackLinks: [{source: browser, target: output}, {source: secondBrowser, target: output}, {source: player, target: output}]
        readonly property var micApps: AudioService.appEntries(recordingNodes, true, recordingLinks, inputs)
        readonly property var playbackApps: AudioService.appEntries(playbackNodes, false, playbackLinks, outputs)
        property bool micActivityEnabled: true
        property bool routingBusy: false
        property string routingError: ""
        property string routingMessage: ""
        property string devicesError: ""
        property bool profileBusy: false
        property var card: ({name: "headset-card", description: "Headset", activeProfile: "duplex", profiles: [
            {name: "duplex", description: "Digital Stereo Output + Mono Input", available: true, input: true, output: true},
            {name: "stereo", description: "Analog Stereo Output", available: true, input: false, output: true},
            {name: "off", description: "Off", available: true, input: false, output: false}
        ]})
        function beginPanel() {}
        function endPanel() {}
        function cardForNode(node) { return node === output || node === input ? card : null }
        function setProfile(deviceCard, profile) { card = Object.assign({}, deviceCard, {activeProfile: profile}) }
        function deviceName(node) { return node.description }
        function isDefault(node, input) { return node === (input ? defaultInput : defaultOutput) }
        function deviceInUse(node, input) { return node === (input ? currentInput : currentOutput) }
        function setDefault(node, input) { if (input) defaultInput = node; else defaultOutput = node }
        function useNow(node, input) { if (input) currentInput = node; else currentOutput = node }
        function moveApp(app, node, input) {
            const links = (input ? recordingLinks : playbackLinks).map(link => app.nodes.includes(input ? link.target : link.source)
                ? Object.assign({}, link, input ? {source: node} : {target: node}) : link)
            if (input) recordingLinks = links
            else playbackLinks = links
        }
        function toggleAppMute(app, input) {
            const current = (input ? micApps : playbackApps).find(item => item.key === app.key)
            AudioService.setAppMute(current, !AudioService.appMuted(current))
        }
        function appMuted(app) { return AudioService.appMuted(app) }
        function appVolume(app) { return AudioService.appVolume(app) }
        function setAppVolume(app, value) { AudioService.setAppVolume(app, value) }
        function toggleNodeMute(node) { AudioService.toggleNodeMute(node) }
        function setNodeVolume(node, value) { AudioService.setNodeVolume(node, value) }
    }
    FloatingWindow {
        visible: true
        implicitWidth: Theme.audioTooltipWidth * 2 + 60
        implicitHeight: 760
        color: Theme.background
        Test.TestCase { id: wheelEvents; when: false }
        Row {
            id: panels
            anchors.centerIn: parent
            spacing: 20
            AudioTooltip { id: outputPanel; audioService: backend }
            AudioTooltip { id: inputPanel; input: true; audioService: backend }
        }
    }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            if (root.step === 0) {
                const screenshot = Quickshell.env("AUDIO_TEST_SCREENSHOT")
                if (screenshot && !root.screenshotTaken) {
                    root.screenshotTaken = true
                    panels.grabToImage(result => result.saveToFile(screenshot))
                    return
                }
                const outputs = root.find(outputPanel, "audioDevices")
                const inputs = root.find(inputPanel, "audioDevices")
                root.check(outputs.count === 2 && inputs.count === 2, "separate device lists")
                root.check(outputPanel.currentIndex === 0 && inputPanel.currentIndex === 0
                    && root.find(outputPanel, "audioAppList").visible && root.find(inputPanel, "audioAppList").visible,
                    "both audio panels open on the Apps tab")
                const appNodes = [
                    {properties: {"application.process.id": "10", "application.name": "Browser", "object.serial": "801"}},
                    {properties: {"application.process.id": "10", "application.name": "Browser", "object.serial": "802"}},
                    {properties: {"application.process.id": "11", "application.name": "Player", "object.serial": "803"}}
                ]
                const apps = AudioService.appEntries(appNodes, false, [
                    {source: appNodes[0], target: output}, {source: appNodes[1], target: secondOutput},
                    {source: appNodes[2], target: output}
                ], [output, secondOutput])
                root.check(apps.length === 2 && apps[0].serials.length === 2 && apps[0].multipleDevices
                    && apps[1].deviceName === "output", "grouped app streams and mixed current devices")
                const captures = AudioService.appEntries(appNodes, true, [
                    {source: input, target: appNodes[0]}, {source: input, target: appNodes[1]}
                ], [input, secondInput])
                root.check(captures[0].deviceName === "input", "recording app current microphone")
                root.check(!AudioService.appEntries([{properties: {"application.name": "Unmapped"}}], false, [], [output])[0].routable,
                    "unmapped app keeps its name without allowing an incorrect route")
                const outputApps = root.find(outputPanel, "audioProcesses")
                root.selectTab(outputPanel, 0)
                root.selectTab(inputPanel, 0)
                let mute = root.find(root.appRow(outputPanel, "process:10"), "appMute")
                root.check(mute.enabled && !mute.highlightedDevice, "app starts unmuted")
                wheelEvents.mouseClick(mute)
                root.check(browser.audio.muted && secondBrowser.audio.muted && !player.audio.muted
                    && !recorder.audio.muted && !output.audio.muted && !input.audio.muted,
                    "app mute affects all of its streams without muting other apps or hardware")
                mute = root.find(root.appRow(outputPanel, "process:10"), "appMute")
                root.check(mute.highlightedDevice && mute.hint === "Unmute Browser", "muted app button updates")
                wheelEvents.mouseClick(mute)
                root.check(!browser.audio.muted && !secondBrowser.audio.muted, "app unmute restores all its streams")
                browser.audio.muted = true
                mute = root.find(root.appRow(outputPanel, "process:10"), "appMute")
                root.check(!mute.highlightedDevice, "partly muted app can mute remaining streams")
                wheelEvents.mouseClick(mute)
                root.check(browser.audio.muted && secondBrowser.audio.muted, "mixed mute state mutes all app streams")
                browser.audio.muted = false
                secondBrowser.audio.muted = false
                root.check(!root.find(root.appRow(outputPanel, "process:10"), "appMute").highlightedDevice,
                    "app mute button follows external changes")
                const browserApp = backend.playbackApps.find(app => app.key === "process:10")
                const appSlider = root.find(root.appRow(outputPanel, "process:10"), "appVolume")
                browser.audio.volume = 0.3
                secondBrowser.audio.volume = 0.5
                root.check(Math.abs(appSlider.value - 0.5) < 0.001
                    && root.find(root.appRow(outputPanel, "process:10"), "appVolumePercentage").text === "50%",
                    "app slider follows the highest stream volume and external changes")
                wheelEvents.mouseClick(appSlider, appSlider.width / 2, appSlider.height / 2)
                root.check(browser.audio.volume > 0.5 && browser.audio.volume === secondBrowser.audio.volume
                    && player.audio.volume === 0 && output.audio.volume === 0.4 && input.audio.volume === 0.65,
                    "app slider changes all its streams without changing other apps or hardware")
                let appLevel = browser.audio.volume
                wheelEvents.mouseWheel(appSlider, appSlider.width / 2, appSlider.height / 2, 0, 120)
                root.check(browser.audio.volume > appLevel && browser.audio.volume === secondBrowser.audio.volume,
                    "app volume supports mouse wheel adjustment")
                appLevel = browser.audio.volume
                appSlider.forceActiveFocus()
                wheelEvents.keyClick(Qt.Key_Right)
                root.check(browser.audio.volume > appLevel, "app volume supports keyboard adjustment")
                AudioService.setAppVolume(browserApp, 2)
                root.check(browser.audio.volume === Config.audioMaxVolume && secondBrowser.audio.volume === Config.audioMaxVolume,
                    "app volume caps at the configured boost limit")
                AudioService.setAppVolume(browserApp, NaN)
                root.check(browser.audio.volume === Config.audioMaxVolume, "invalid app volume is ignored")
                AudioService.setAppVolume(browserApp, -1)
                root.check(browser.audio.volume === 0 && secondBrowser.audio.volume === 0, "app volume caps at zero")
                AudioService.setAppVolume(null, 0.5)
                const recordingSlider = root.find(root.appRow(inputPanel, "process:20"), "appVolume")
                root.check(recordingSlider.visible && recordingSlider.enabled, "recording app gain control is available")
                wheelEvents.mouseClick(recordingSlider, recordingSlider.width / 2, recordingSlider.height / 2)
                root.check(recorder.audio.volume > 0 && call.audio.volume === 0 && browser.audio.volume === 0
                    && input.audio.volume === 0.65 && output.audio.volume === 0.4 && !recorder.audio.muted,
                    "recording app gain preserves other apps, hardware gain, playback, and mute state")
                recorder.audio.volume = 0.35
                root.check(Math.abs(recordingSlider.value - 0.35) < 0.001
                    && root.find(root.appRow(inputPanel, "process:20"), "appVolumePercentage").text === "35%",
                    "recording app gain follows external changes")
                wheelEvents.mouseWheel(recordingSlider, recordingSlider.width / 2, recordingSlider.height / 2, 0, 120)
                root.check(recorder.audio.volume > 0.35 && input.audio.volume === 0.65,
                    "recording app gain supports wheel adjustment independently of the microphone")
                recorder.ready = false
                const recordingLevel = recorder.audio.volume
                AudioService.setAppVolume(backend.micApps.find(app => app.key === "process:20"), 0.5)
                root.check(!recordingSlider.enabled && recorder.audio.volume === recordingLevel,
                    "unavailable recording stream is not adjusted")
                recorder.ready = true
                wheelEvents.mouseClick(root.find(root.appRow(inputPanel, "process:20"), "appMute"))
                root.check(recorder.audio.muted && !call.audio.muted && !input.audio.muted && !browser.audio.muted,
                    "recording app mute preserves other recording apps and playback")
                wheelEvents.mouseClick(root.find(root.appRow(inputPanel, "process:20"), "appMute"))
                root.check(!recorder.audio.muted, "recording app unmute")
                player.ready = false
                root.check(!root.find(root.appRow(outputPanel, "process:11"), "appMute").enabled,
                    "unavailable app mute control disabled")
                AudioService.setAppMute(backend.playbackApps.find(app => app.key === "process:11"), true)
                root.check(!player.audio.muted, "unavailable stream is not mutated")
                AudioService.setAppVolume(backend.playbackApps.find(app => app.key === "process:11"), 0.5)
                root.check(!root.find(root.appRow(outputPanel, "process:11"), "appVolume").enabled
                    && player.audio.volume === 0, "unavailable app volume control is disabled and its stream is not mutated")
                player.ready = true
                AudioService.setAppMute(null, true)
                let selector = root.find(outputApps.itemAt(0), "appDeviceSelector")
                root.check(selector.selectedDescription === "Headphones", "app current output shown")
                wheelEvents.mouseClick(root.find(selector, "selectorToggle"))
                let choices = root.find(selector, "selectorChoices")
                choices.forceLayout()
                choices.itemAtIndex(1).clicked()
                root.check(backend.playbackApps[0].deviceName === "second-output" && backend.playbackApps[1].deviceName === "output"
                    && backend.defaultOutput === output, "moving one playback app preserves other apps and default")
                selector = root.find(root.appRow(inputPanel, "process:20"), "appDeviceSelector")
                wheelEvents.mouseClick(root.find(selector, "selectorToggle"))
                choices = root.find(selector, "selectorChoices")
                choices.forceLayout()
                choices.itemAtIndex(1).clicked()
                root.check(backend.micApps.find(app => app.key === "process:20").deviceName === "second-input"
                    && backend.micApps.find(app => app.key === "process:21").deviceName === "input"
                    && backend.defaultInput === input, "moving one recording app preserves other apps and default")
                selector = root.find(root.find(outputPanel, "audioProcesses").itemAt(0), "appDeviceSelector")
                root.check(selector.selectedDescription === "Speakers", "app selector follows routing change")
                root.selectTab(outputPanel, 1)
                root.selectTab(inputPanel, 1)
                const outputList = root.find(outputPanel, "audioDeviceList")
                outputList.contentY = Math.max(0, outputList.contentHeight - outputList.height)
                const row = outputs.itemAt(1)
                wheelEvents.mouseClick(root.find(row, "deviceUseNow"))
                root.check(backend.currentOutput === secondOutput && backend.defaultOutput === output, "Use now leaves default unchanged")
                root.find(row, "deviceDefault").clicked()
                root.check(backend.defaultOutput === secondOutput && row.isDefault, "default marker follows selected output")
                wheelEvents.mouseClick(root.find(row, "deviceMute"))
                root.check(secondOutput.audio.muted && !output.audio.muted, "mute affects only its device")
                const slider = root.find(row, "deviceVolume")
                slider.value = 0.77
                slider.moved()
                root.check(Math.abs(secondOutput.audio.volume - 0.77) < 0.001, "slider updates its device")
                secondOutput.audio.volume = 0.31
                root.check(Math.abs(slider.value - 0.31) < 0.001, "slider follows external changes")
                wheelEvents.mouseWheel(slider, slider.width / 2, slider.height / 2, 0, 120)
                root.check(secondOutput.audio.volume > 0.31, "real wheel event increases output volume")
                const wheelLevel = secondOutput.audio.volume
                wheelEvents.mouseWheel(slider, slider.width / 2, slider.height / 2, 0, -120)
                root.check(secondOutput.audio.volume < wheelLevel, "real wheel event decreases output volume")
                const micRow = inputs.itemAt(0)
                const micSlider = root.find(micRow, "deviceVolume")
                wheelEvents.mouseWheel(micSlider, micSlider.width / 2, micSlider.height / 2, 0, 120)
                root.check(input.audio.volume > 0.65, "real wheel event increases microphone gain")
                const profile = root.find(outputs.itemAt(0), "deviceProfile")
                wheelEvents.mouseClick(root.find(profile, "profileToggle"))
                root.check(profile.expanded && profile.profiles.length === 3, "profile menu opens")
                const profiles = root.find(profile, "profileChoices")
                profiles.forceLayout()
                profiles.itemAtIndex(1).clicked()
                root.check(backend.card.activeProfile === "stereo" && !profile.expanded
                    && root.find(micRow, "deviceProfile").activeDescription === "Analog Stereo Output", "profile selection updates both panels")
                root.find(micRow, "deviceMute").clicked()
                root.check(input.audio.muted, "microphone mute")
                AudioService.setNodeVolume(input, 2)
                root.check(input.audio.volume === Config.audioMaxVolume, "volume caps at configured boost limit")
                AudioService.setNodeVolume(input, 1.25)
                root.check(input.audio.volume === 1.25, "microphone gain can exceed 100 percent")
                AudioService.setNodeVolume(secondOutput, 1.25)
                root.check(secondOutput.audio.volume === 1.25 && slider.to === Config.audioMaxVolume && slider.wheelEnabled,
                    "output boost and wheel enabled")
                AudioService.setNodeVolume(input, -1)
                root.check(input.audio.volume === 0, "volume caps at zero")
                AudioService.toggleNodeMute(null)
                AudioService.setNodeVolume(null, 0.5)
                root.check(root.find(inputPanel, "micActivityHint").text === "Mic activity enabled", "activity status preserved")
                root.check(!root.find(inputPanel, "audioAppsTitle").visible
                    && !root.find(outputPanel, "audioAppsTitle").visible, "active apps have no extra heading")
                root.check(root.find(inputPanel, "audioProcesses").count === 2 && root.find(outputPanel, "audioProcesses").count === 2, "both process lists preserved")
                backend.micActivityEnabled = false
                recorder.appName = "New recorder"
                browser.appName = "New player"
                backend.recordingNodes = [recorder]
                backend.playbackNodes = [browser]
                backend.outputs = Array(12).fill(output)
            } else if (root.step === 1) {
                root.check(root.find(inputPanel, "micActivityHint").text === "Mic activity disabled", "activity status updates")
                root.check(root.find(root.find(inputPanel, "audioProcesses").itemAt(0), "audioAppName").text === "New recorder"
                    && root.find(root.find(outputPanel, "audioProcesses").itemAt(0), "audioAppName").text === "New player", "process lists update")
                const list = root.find(outputPanel, "audioDeviceList")
                root.check(list.contentHeight > list.height && outputPanel.height <= outputPanel.maxPanelHeight, "panel height capped and scrollable")
                list.contentY = list.contentHeight - list.height
                const savedPosition = list.contentY
                root.selectTab(outputPanel, 0)
                root.selectTab(outputPanel, 1)
                root.check(list.contentY === savedPosition, "device scroll position survives tab switching")
                backend.outputs = []
                backend.playbackNodes = Array.from({length: 12}, (_, index) => ({
                    ready: true, audio: browser.audio,
                    properties: {"application.name": "App " + index, "application.process.id": String(100 + index),
                        "object.serial": String(900 + index)}
                }))
            } else if (root.step === 2) {
                root.check(root.find(outputPanel, "audioDevices").count === 0, "disconnected devices removed")
                root.check(!root.find(root.find(outputPanel, "audioProcesses").itemAt(0), "appDeviceSelector").enabled,
                    "app selection disabled when no destination is available")
                const appList = root.find(outputPanel, "audioAppList")
                const deviceList = root.find(outputPanel, "audioDeviceList")
                const devicePosition = deviceList.contentY
                root.selectTab(outputPanel, 0)
                root.check(appList.contentHeight > appList.height && outputPanel.height <= outputPanel.maxPanelHeight,
                    "long app list is capped and scrollable")
                appList.contentY = appList.contentHeight - appList.height
                root.check(appList.contentY > 0 && deviceList.contentY === devicePosition,
                    "scrolling apps preserves the device list position")
                backend.playbackNodes = []
                backend.recordingNodes = []
            } else if (root.step === 3) {
                root.selectTab(inputPanel, 0)
                root.check(root.find(outputPanel, "audioProcesses").count === 0 && root.find(inputPanel, "audioProcesses").count === 0,
                    "stopped apps removed")
                root.check(root.find(inputPanel, "audioAppsTitle").text === "No apps recording"
                    && root.find(outputPanel, "audioAppsTitle").text === "No apps playing audio", "empty app titles")
                if (!root.failed) console.log("PASS: audio panels, individual app routing, mute and volume, device controls, preserved activity and processes, live updates, scrolling")
                Qt.quit()
            }
            root.step++
        }
    }
}
