pragma Singleton
import Quickshell.Io
import "../"
import "../../config"

// The main launcher owns desktop actions and bridge IPC; Clipboard has its own session.
PickerSession {
    id: root
    enum Mode { None, Menu, Projects, Directories, Apps, Windows, Clipboard, Secret, Webapps, Remotes, N8n }
    function clipboard() { ClipboardPickerService.clipboard() }
    IpcHandler {
        target: "launcher"
        function apps(): void { root.apps() }
        function power(): void { PowerService.open() }
        function bookmarks(): void { BookmarkService.open() }
        function screenshot(method: string): void { ScreenshotService.open(method) }
        function screenshotStatus(): string { return ScreenshotService.snapshot() }
        function encodeQr(): void { QrEncodeService.open() }
        function wallpaper(directory: string): void { WallpaperService.open(directory) }
        function windows(scope: string): void { root.windows(scope) }
        function expose(scope: string): void { root.expose(scope) }
        function clipboard(): void { root.clipboard() }
        function projects(): void { root.projects() }
        function directories(): void { root.directories() }
        function n8n(): void { root.n8n() }
        function remotes(): void { root.remotes() }
        function webapps(): void { root.webapps() }
        function projectUrls(): void { root.projects(true) }
        function providerConfig(): string { return JSON.stringify(Config.providerEnvironment) }
        function open(directory: string): void { root.open(directory) }
        function cancel(directory: string): void { root.cancel(directory) }
        function alive(): bool { return true }
    }
}
