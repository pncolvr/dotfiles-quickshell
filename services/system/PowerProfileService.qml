pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"

Singleton {
    id: root

    readonly property string profile: _internal.profile

    QtObject {
        id: _internal
        property string profile: Config.powerProfilesDefaultProfile
    }

    function cycleProfile() {
        const profiles = Config.powerProfiles
        const next = profiles[(profiles.indexOf(root.profile) + 1) % profiles.length]
        setProcess.command = Config.powerProfilesSetCommand.concat([next])
        setProcess.running = true
    }

    Process {
        id: getProcess
        running: true
        command: Config.powerProfilesGetCommand
        stdout: SplitParser {
            onRead: data => {
                // console.debug("PowerProfileService: fetched profile:", data.trim())
                _internal.profile = data.trim()
            }
        }
    }

    Process {
        id: setProcess
        onRunningChanged: if (!running) getProcess.running = true
    }
}