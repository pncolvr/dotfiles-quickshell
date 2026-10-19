pragma Singleton
pragma ComponentBehavior: Bound
import QtQml
import QtQml.Models
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../config"
import "Catalog.mjs" as Catalog

Singleton {
    id: root
    readonly property string systemLocale: Qt.locale().name
    readonly property var catalogs: state.catalogs
    readonly property var availableLanguages: Object.keys(catalogs).sort()
    readonly property string language: Catalog.language(Config.language, systemLocale, availableLanguages)
    readonly property var fallback: catalogs.en ?? ({})
    readonly property var messages: catalogs[language] ?? fallback
    readonly property var locale: Qt.locale(messages.$locale || language)
    readonly property var calendarMonthNames: list('calendar.months')
    readonly property var calendarDayNames: list('calendar.weekdays')

    function text(key, args = [], count = -1) {
        return Catalog.text(key, messages, fallback, args, count)
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
        const value = Catalog.entry(key, messages, fallback)
        return Array.isArray(value) ? value : []
    }
    QtObject { id: state; property var catalogs: ({}) }
    function loadCatalog(code, messages) {
        state.catalogs = Object.assign({}, catalogs, {[code]: messages})
    }
    function removeCatalog(code) {
        const remaining = Object.assign({}, catalogs)
        delete remaining[code]
        state.catalogs = remaining
    }
    // Native folder discovery and one generic reader per catalog; no subprocesses
    // or locale polling. File names are the dictionary's language identifiers.
    FolderListModel {
        id: languages
        folder: Qt.resolvedUrl('languages')
        nameFilters: ['*.json']
        showDirs: false
    }
    component CatalogFile: FileView {
        required property string fileName
        required property url fileUrl
        readonly property string languageCode: fileName.slice(0, -5)
        path: fileUrl
        preload: true
        blockLoading: true
        onLoaded: root.loadCatalog(languageCode, Catalog.parse(text()))
    }
    Instantiator {
        model: languages
        delegate: CatalogFile {}
        onObjectRemoved: (index, object) => {
            const reader = object as CatalogFile
            root.removeCatalog(reader.languageCode)
        }
    }
}
