import QtQuick
import Quickshell
import Quickshell.Networking
import "../../src/services"

Scope {
    id: root
    property bool failed: false
    function check(condition, message) {
        if (!condition) { failed = true; console.error("SERVICES FAIL: " + message) }
    }

    Component.onCompleted: {
        NetworkService.devices = [{name: "wlan0", type: DeviceType.Wifi, connected: true,
            networks: {values: [{name: "Cafe:Home\\Office", connected: true}]}}]
        NetworkService.active = true
    }
    Timer {
        interval: 300
        running: true
        onTriggered: {
            NetworkService.active = false
            const network = NetworkService.connectedNetworks[0]
            root.check(network?.name === "Cafe:Home\\Office" && network.type === "wifi" && network.connected,
                "native connected device profile fields")
            const vpn = NetworkService.vpnConnections[0]
            root.check(vpn?.name === "Work:VPN\\Office" && vpn.type === "vpn" && vpn.active, "escaped VPN fields")

            NetworkService.applyNetworkSample("eth0 1000 2000\ntun0 1000 2000\nlo 999 999", 10000)
            NetworkService.applyNetworkSample("eth0 1400 2200\ntun0 1200 2100", 12000)
            root.check(NetworkService.downloadSpeed === 300 && NetworkService.uploadSpeed === 150,
                "rates use actual elapsed time instead of polling configuration")
            NetworkService.applyNetworkSample("eth0 1400 2200", 13000)
            root.check(NetworkService.downloadSpeed === 0 && NetworkService.uploadSpeed === 0,
                "removed interface stops contributing traffic")
            NetworkService.applyNetworkSample("eth0 1400 2200\ntun0 900000 900000", 14000)
            root.check(NetworkService.downloadSpeed === 0, "reappearing interface gets a fresh baseline")
            NetworkService.applyNetworkSample("eth0 10 10\ntun0 10 10", 15000)
            root.check(NetworkService.downloadSpeed === 0 && NetworkService.uploadSpeed === 0, "counter resets")
            NetworkService.applyNetworkSample("eth0 20 20", 14000)
            root.check(NetworkService.downloadSpeed === 0, "backwards clock does not produce invalid rates")
            NetworkService.applyNetworkSample("", 16000)
            root.check(NetworkService.downloadSpeed === 0, "empty interface snapshot removes all rates")
            for (let index = 0; index < 70; index++) NetworkService.applyNetworkSample("eth0 20 20", 17000 + index * 1000)
            root.check(NetworkService.speedHistory.length === 60, "history stays bounded")
            console.log(root.failed ? "SERVICES FAIL: network" : "PASS: network samples and escaped profiles")
            Qt.quit()
        }
    }
}
