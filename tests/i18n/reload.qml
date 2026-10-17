import QtQml
import Quickshell
import Quickshell.Io
import "../../src/i18n"

Scope {
    IpcHandler {
        target: "i18ncheck"
        function label(): string { return Translations.text("common.actions.save") }
        function reload(): void { Qt.callLater(() => Quickshell.reload(true)) }
    }
}
