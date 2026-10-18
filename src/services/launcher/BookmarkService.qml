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
    property int tab: 0
    property var bookmarks: []
    readonly property bool enabled: Config.bookmarksEnabled && (Config.browserRoutingEnabled || Config.bookmarkFile.trim().length > 0)
    onEnabledChanged: if (!enabled && ownsMenu()) PickerService.close()

    function parse(text) {
        return text.split(/\r?\n/).map(line => line.trim()).filter(line => line.length > 0).map(line => {
            const parts = /^(\S+)(?:\s+(.*))?$/.exec(line)
            return {title: parts[2] || parts[1], result: parts[1]}
        })
    }
    function open() {
        if (!enabled) return
        tab=0
        BrowserRoutingService.managing=false
        BrowserRoutingService.cancel()
        callback = rows => root.launch(rows)
        PickerService.promptMenu("", [], callback, "list", {
            allowMultipleSelection: true, allowTyped: true, acceptLabel: Translations.text("bookmarks.actions.open")
        })
        if(Config.bookmarkFile.trim()) {
            source.reload()
            source.text() // Start the lazy FileView read without blocking input focus.
        } else publish('')
    }
    function ownsMenu() {
        return PickerService.visible && PickerService.mode === PickerService.Mode.Menu
            && !!callback && PickerService.menuCallback === callback
    }
    function publish(text) {
        if (!enabled || !ownsMenu()) return
        const rows = parse(text)
        bookmarks=rows
        if (Config.browserRoutingEnabled) {
            if (tab===0) PickerService.items=PickerService.menuRows(rows,true)
            return
        }
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
            Quickshell.execDetached(Config.browserOpenCommand.concat([row.result]))
        }
    }
    function setTab(index) {
        BrowserRoutingService.cancel()
        tab=index
        BrowserRoutingService.managing=index===2
        PickerService.error=''
        PickerService.query=''; PickerService.selectedIds=[]; PickerService.currentIndex=0
        PickerService.allowTyped=index===0
        if(index===0) PickerService.items=PickerService.menuRows(bookmarks,true)
        else if(index===1) publishHistory()
        else PickerService.items=[]
    }
    function publishHistory() {
        if(!ownsMenu() || tab!==1) return
        PickerService.items=BrowserRoutingRepository.history(PickerService.query).map(row=>{
            const browser=Config.browsers.find(entry=>entry.id===row.browser)?.name || row.browser
            return {id:row.url,title:row.url,subtitle:browser,annotation:row.rule_name,result:row.url,search:row.url+' '+row.browser,
                hint:Translations.text('browser.routing.historyDetails',[row.url,row.final_url,browser,row.rule_name || '—'])}
        })
    }
    Connections { target:PickerService; function onQueryChanged() { if(root.tab===1) root.publishHistory() } }
    Connections { target:BrowserRoutingRepository; function onRevisionChanged() { root.publishHistory() } }
    Connections { target:Config; function onBrowserRoutingEnabledChanged() { if(root.ownsMenu()) root.setTab(0) } }
    FileView {
        id: source
        path: root.enabled ? Config.bookmarkFile : ""
        preload: false
        blockLoading: false
        printErrors: false
        onLoaded: root.publish(text())
        onLoadFailed: if (root.enabled && root.ownsMenu() && root.tab===0) PickerService.error = Translations.text("bookmarks.errors.read")
    }
}
