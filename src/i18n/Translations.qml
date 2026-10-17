pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import "../config"
import "Catalog.mjs" as Catalog

Singleton {
    id: root
    readonly property string systemLocale: Qt.locale().name
    readonly property string language: Catalog.language(Config.language, systemLocale)
    readonly property var locale: Qt.locale(language === 'pt' ? 'pt_PT' : 'en_GB')
    readonly property var english: Catalog.parse(englishFile.text())
    readonly property var portuguese: Catalog.parse(portugueseFile.text())
    readonly property var messages: language === 'pt' ? portuguese : english
    readonly property var calendarMonthNames: list('calendar.months')
    readonly property var calendarDayNames: list('calendar.weekdays')

    function text(key, args = [], count = -1) {
        return Catalog.text(key, messages, english, args, count)
    }
    // A shared boundary for helper diagnostics. Unknown external-tool output stays literal.
    function message(value) {
        let diagnostic = value;
        if (typeof value === "string") {
            try { diagnostic = JSON.parse(value) } catch (_) { return text(value) }
        }
        if (diagnostic instanceof Error) return text(diagnostic.message,diagnostic.args ?? []);
        if (diagnostic && typeof diagnostic.key === "string")
            return text(diagnostic.key, Array.isArray(diagnostic.args) ? diagnostic.args : [], diagnostic.count ?? -1);
        return typeof value === "string" ? text(value) : "";
    }
    function list(key) {
        const value = Catalog.entry(key, messages, english)
        return Array.isArray(value) ? value : []
    }
    // Packaged, small catalogs load once. No external commands, watchers or locale polling.
    FileView { id: englishFile; path: Qt.resolvedUrl('en.json'); preload: true; blockLoading: true }
    FileView { id: portugueseFile; path: Qt.resolvedUrl('pt.json'); preload: true; blockLoading: true }
}
