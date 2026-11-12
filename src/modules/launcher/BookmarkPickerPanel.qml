pragma ComponentBehavior: Bound
import QtQuick
import "../../ui" as UI
import "../../theme"
import "../../services"
import "../../i18n"

Item {
    id: root
    property var picker: PickerService
    property bool backgroundVisible: true
    readonly property bool nativeDialogOpen: manager.nativeDialogOpen
    readonly property bool dismissOnOutside: BookmarkService.tab!==2
    readonly property real radius: Theme.tooltipRadius
    implicitWidth: BookmarkService.tab===2 ? Theme.manageWidth : Theme.pickerWidth
    implicitHeight: tabs.height+Theme.controlSpacing+(BookmarkService.tab===2 ? manager.implicitHeight : list.implicitHeight)
    function focusSearch() { if(BookmarkService.tab===2) manager.focusSearch(); else list.focusSearch() }
    UI.TabBar {
        id:tabs; width:parent.width
        labels:[Translations.text('bookmarks.title'),Translations.text('browser.routing.history'),Translations.text('common.tabs.manage')]
        currentIndex:BookmarkService.tab
        onTabClicked:index=>{ BookmarkService.setTab(index); Qt.callLater(root.focusSearch) }
    }
    MultiSelectPickerPanel {
        id:list
        searchPlaceholder: PickerPrompts.text(BookmarkService.tab === 1 ? "history" : "bookmarks", BookmarkService.tab === 1 ? "browser.routing.historySearchPlaceholder" : "bookmarks.search.placeholder")
        y:tabs.height+Theme.controlSpacing; width:parent.width; height:parent.height-y
        picker:root.picker; backgroundVisible:root.backgroundVisible
        uniformRows:BookmarkService.tab===1
        visible:BookmarkService.tab!==2
        typedHint: BookmarkService.tab===0 && BookmarkService.searchTarget(root.picker.query)
            ? Translations.text('bookmarks.search.typedHint') : ''
        typedControls: BookmarkService.tab===0 && BookmarkService.searchTarget(root.picker.query) ? sessionEngine : null
        actionButtons: Component {
            Row {
                layoutDirection:Qt.RightToLeft
                spacing:Theme.controlSpacing
                UI.ActionButton { glyph:Theme.openLinksIcon; hint:Translations.text('bookmarks.actions.open'); enabled:root.picker.canAccept; onClicked:root.picker.accept(false,false) }
                UI.ActionButton { glyph:Theme.selectVisibleIcon; hint:Translations.text('picker.actions.selectVisible'); enabled:root.picker.filteredItems.length>0; onClicked:root.picker.toggleVisibleSelection() }
                UI.ActionButton {
                    objectName:'browserHistoryRoute'; visible:BookmarkService.tab===1
                    glyph:Theme.addIcon; hint:Translations.text('browser.routing.addRule')
                    enabled:!!root.picker.currentItem
                    onClicked:{ const url=root.picker.currentItem.result; BookmarkService.setTab(2); BrowserRoutingService.ruleForUrl(url); Qt.callLater(root.focusSearch) }
                }
                UI.ActionButton {
                    objectName:'browserHistoryRemove'; visible:BookmarkService.tab===1
                    glyph:Theme.deleteIcon; hint:Translations.text('browser.routing.removeHistory'); enabled:!!root.picker.currentItem
                    onClicked:{ BrowserRoutingRepository.removeHistory(root.picker.currentItem.result); BookmarkService.publishHistory() }
                }
                UI.ActionButton {
                    objectName:'browserHistoryClear'; visible:BookmarkService.tab===1
                    glyph:Theme.clearIcon; hint:Translations.text('browser.routing.clearHistory'); enabled:BrowserRoutingRepository.historyCount>0
                    onClicked:{ BrowserRoutingRepository.clearHistory(); BookmarkService.publishHistory() }
                }
            }
        }
    }
    ManagedCollectionPanel {
        id:manager
        searchPromptKey: "browserRouting"
        objectName:'browserRoutingManager'
        y:tabs.height+Theme.controlSpacing; width:parent.width; height:parent.height-y
        picker:root.picker; backgroundVisible:root.backgroundVisible; visible:BookmarkService.tab===2
        tabsVisible:false
        manageSequence:''
        filterCategory:false
        entrySubtitle:entry=>BrowserRoutingService.ruleSubtitle(entry)
        service:BrowserRoutingService; collectionName:Translations.text('browser.routing.rules'); pickerMode:PickerService.Mode.Menu
        entryForm:BrowserRoutingForm {}
        managementHeaderContent: Column {
            objectName:'bookmarkSearchSettings'
            width:parent.width
            spacing:Theme.controlSpacing
            UI.ComboSelector {
                id:engine; objectName:'bookmarkSearchEngine'; width:parent.width; compact:true
                label:Translations.text('bookmarks.settings.engine',[selectedDescription])
                hint:Translations.text('bookmarks.settings.engineHint')
                selectedName:BookmarkService.searchEngine
                options:BookmarkService.searchEngines.map(entry=>({name:entry.id,description:entry.name}))
                    .concat([{name:'custom',description:Translations.text('bookmarks.settings.custom')},{name:'none',description:Translations.text('bookmarks.settings.none')}])
                onSelected:name=>BookmarkService.setSearchEngine(name)
            }
            UI.LabeledField {
                id:template; inputObjectName:'bookmarkSearchTemplate'; width:parent.width
                visible:BookmarkService.searchEngine==='custom'
                label:Translations.text('bookmarks.settings.template')
                hint:Translations.text('bookmarks.settings.templateHint')
                placeholderText:'https://search.example/?q={query}'
                text:BookmarkService.searchTemplate
                onTextChanged:if(text.trim()!==BookmarkService.searchTemplate) saveTemplate.restart()
                onAccepted:saveTemplate.triggered()
                Timer { id:saveTemplate; interval:400; onTriggered:BookmarkService.setSearchTemplate(template.text) }
            }
            UI.ColumnText {
                width:parent.width; wrapMode:Text.Wrap; color:Theme.inactive
                readonly property string preview:BookmarkService.searchUrl('hello world')
                text:BookmarkService.searchEngine==='none' ? Translations.text('bookmarks.settings.disabled')
                    : preview ? Translations.text('bookmarks.settings.preview',[preview]) : Translations.text('bookmarks.settings.invalid')
            }
        }
        detailActionContent: [
            UI.ActionButton {
                objectName:'browserRuleMoveUp'
                glyph:Theme.upIcon
                hint:Translations.text('browser.routing.moveUp')
                enabled:!BrowserRoutingService.busy && BrowserRoutingService.entries.findIndex(entry=>entry.id===manager.selectedEntry?.id)>0
                onClicked:BrowserRoutingService.moveEntry(manager.selectedEntry.id,-1)
            },
            UI.ActionButton {
                objectName:'browserRuleMoveDown'
                glyph:Theme.downIcon
                hint:Translations.text('browser.routing.moveDown')
                enabled:!BrowserRoutingService.busy && !!manager.selectedEntry
                    && BrowserRoutingService.entries.findIndex(entry=>entry.id===manager.selectedEntry.id)<BrowserRoutingService.entries.length-1
                onClicked:BrowserRoutingService.moveEntry(manager.selectedEntry.id,1)
            }
        ]
    }
    Component {
        id:sessionEngine
        UI.ComboSelector {
            objectName:'bookmarkSessionEngine'; width:Theme.pickerWidth/2; compact:true
            hint:Translations.text('bookmarks.search.engineHint')
            selectedName:BookmarkService.activeEngine
            options:BookmarkService.sessionEngines
            onSelected:name=>{ BookmarkService.sessionEngine=name; Qt.callLater(root.focusSearch) }
        }
    }
    Connections { target:root.picker; function onClosed() { BrowserRoutingService.cancel() } }
    UI.PanelShortcut { owner:root; action:'manage'; onActivated:{ BookmarkService.setTab(BookmarkService.tab===2 ? 0 : 2); Qt.callLater(root.focusSearch) } }
    UI.PanelShortcut { owner:root; action:'bookmarks.history'; onActivated:{ BookmarkService.setTab(1); Qt.callLater(root.focusSearch) } }
}
