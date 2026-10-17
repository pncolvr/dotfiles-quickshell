pragma Singleton

import "../../i18n"
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"

Singleton {
    id: root
    property var callback: null
    readonly property bool enabled: Config.bookmarksEnabled && Config.bookmarkFile.trim().length > 0
    onEnabledChanged: if (!enabled && ownsMenu()) PickerService.close()

    function parse(text) {
        return text.split(/\r?\n/).map(line => line.trim()).filter(line => line.length > 0).map(line => {
            const parts = /^(\S+)(?:\s+(.*))?$/.exec(line)
            return {title: parts[2] || parts[1], result: parts[1]}
        })
    }
    function open() {
        if (!enabled) return
        callback = rows => root.launch(rows)
        PickerService.promptMenu("", [], callback, "list", {
            allowMultipleSelection: true, allowTyped: true, acceptLabel: Translations.text("bookmarks.actions.open")
        })
        source.reload()
        source.text() // Start the lazy FileView read without blocking input focus.
    }
    function ownsMenu() {
        return PickerService.visible && PickerService.menuCallback === callback
    }
    function publish(text) {
        if (!enabled || !ownsMenu()) return
        const rows = parse(text)
        switch (rows.length) {
          case 0:
            PickerService.close()
            break
          case 1:
            PickerService.close()
            launch(rows)
            break
          default:
            PickerService.items = PickerService.menuRows(rows, true)
        }
    }
    function launch(rows) {
        if (!enabled) return
        for (const row of rows) {
            if (!row.result) continue
            Quickshell.execDetached(Config.bookmarkBrowserCommand.concat([row.result]))
        }
    }
    FileView {
        id: source
        path: root.enabled ? Config.bookmarkFile : ""
        preload: false
        blockLoading: false
        printErrors: false
        onLoaded: root.publish(text())
        onLoadFailed: if (root.enabled && root.ownsMenu()) PickerService.error = Translations.text("bookmarks.errors.read")
    }
}
