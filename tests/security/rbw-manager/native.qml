pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Quickshell.Wayland
import "../../../src/services"
import "../../../src/modules/vault"
WorkerScope {
    id: root
    VaultWindow { id: window }
    IpcHandler {
        target: "rbwtest"
        function open(): void { RbwService.open() }
        function snapshot(): string { return JSON.stringify({visible:window.visible,busy:RbwService.busy,count:RbwService.entries.length,namespace:window.WlrLayershell.namespace,editing:window.panel?.editing,details:!!RbwService.detail}) }
        function select(): void { RbwService.select("11111111-1111-1111-1111-111111111111") }
        function newLogin(): void { if (window.panel) window.panel.newLogin() }
        function close(): void { RbwService.close() }
    }
}
