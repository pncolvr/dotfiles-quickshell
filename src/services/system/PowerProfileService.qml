pragma Singleton

import QtQml
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root
    readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver"
        : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    readonly property var availableProfiles: PowerProfiles.hasPerformanceProfile
        ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"]
    function setProfile(name) {
        if (!availableProfiles.includes(name)) return false
        const profiles = {"power-saver": PowerProfile.PowerSaver, "balanced": PowerProfile.Balanced, "performance": PowerProfile.Performance}
        PowerProfiles.profile = profiles[name]
        return true
    }
}
