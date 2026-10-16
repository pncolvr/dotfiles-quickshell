import QtQuick
import Quickshell
import "../../src/services" as Services
import "../../src/services/storage" as Storage
import "../../src/services/clipboard" as Clipboard
import "../../src/services/audio" as Audio
import "../../src/services/time" as Time
import "../../src/services/recording" as Recording
import "../../src/services/n8n" as N8n
import "../../src/config" as Settings
import "../../src/theme" as Styling
import "../../src/theme/ui" as UI
import "../../src/theme/ui/components" as Components

Scope {
    id: root
    property int ticks: 0
    property bool failed: false
    function check(ok,message) { if (!ok) { failed = true; console.error("SINGLETON FAIL:",message) } }
    Audio.ScreencastModel { id: screenModel; nodes: []; links: [] }
    Components.ColumnText { id: localText; text: "Local component" }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (++root.ticks > 200) { root.check(false,"storage readiness timed out"); stop(); Qt.quit(); return }
            if (!Services.DbService.ready) return
            stop()
            const pairs = [
                ["DbService",Services.DbService,Storage.DbService],
                ["Timespan",Services.Timespan,Time.Timespan],
                ["RecordingService",Services.RecordingService,Recording.RecordingService],
                ["N8nService",Services.N8nService,N8n.N8nService],
                ["N8nRepository",Services.N8nRepository,Storage.N8nRepository],
                ["Theme",Settings.Theme,Styling.Theme],
                ["PreferencesRepository",Services.PreferencesRepository,Storage.PreferencesRepository],
                ["ClipboardRepository",Services.ClipboardRepository,Storage.ClipboardRepository],
                ["ProjectRepository",Services.ProjectRepository,Storage.ProjectRepository],
                ["DirectoryRepository",Services.DirectoryRepository,Storage.DirectoryRepository],
                ["BatteryRepository",Services.BatteryRepository,Storage.BatteryRepository],
                ["NotificationRepository",Services.NotificationRepository,Storage.NotificationRepository],
                ["NotificationEmitterRepository",Services.NotificationEmitterRepository,Storage.NotificationEmitterRepository],
                ["TwitchRepository",Services.TwitchRepository,Storage.TwitchRepository],
                ["TextureSettings",UI.TextureSettings,Components.TextureSettings],
                ["ImageCropCache",UI.ImageCropCache,Components.ImageCropCache],
                ["MotionPolicy",UI.MotionPolicy,Components.MotionPolicy],
                ["SensitiveClipboardService",Services.SensitiveClipboardService,Clipboard.SensitiveClipboardService]
            ]
            for (const pair of pairs) root.check(pair[1] === pair[2],pair[0] + " resolves to one shared instance")
            root.check(Services.PreferencesRepository.setValue("singleton-metadata-test",{value:73}),"write private fixture preference")
            root.check(Storage.PreferencesRepository.value("singleton-metadata-test",{}).value === 73,"local imports observe parent writes")
            root.check(screenModel.streams.length === 0 && localText.text === "Local component","existing local helper types remain available")
            root.check(Settings.Config.timerTickInterval === Time.Timespan.fromMilliseconds(250),"Config imports the shared time utility")
            root.check(Settings.Config.updatesRefreshCommand[1] === Quickshell.shellPath("src/services/system/update-check.sh"),"update helper resolves from the shell root")
            if (!root.failed) console.log("PASS: local singleton metadata preserves shared instances, storage state and helper types")
            Qt.quit()
        }
    }
}
