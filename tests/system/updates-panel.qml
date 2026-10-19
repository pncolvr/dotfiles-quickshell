pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../src/modules/updates" as Updates
import "../../src/ui" as UI
import "../../src/theme"
import "../../src/config"
import "../../src/services"
import "../launcher" as Support

Scope {
    id: root
    property var settings: Config
    function find(name) { return driver.find(panel, name) }
    function section(name) { return find("updates" + name + "Section") }
    function label(name) { return find("updates" + name + "SectionCount") as UI.ColumnText }
    function rows(name) { return section(name).children.filter(item => item instanceof Updates.UpdateRow) }
    function snapshot() {
        return ['core x86_64 linux 1.0 2.0', 'core x86_64 systemd 252 253',
            'extra x86_64 example 1.1 1.2', 'aur any example-tools 1.0 2.0', 'extra x86_64 alpha 5 6']
            .concat(Array.from({length:62}, (_, index) => 'extra x86_64 package-' + index + ' 3 4')).join('\n')
    }
    function refresh(snapshot) {
        settings.updatesCheckCommand = ['printf', '%s', snapshot]
        UpdatesService.refresh()
    }
    FloatingWindow {
        visible: true
        implicitWidth: 380
        implicitHeight: 900
        Updates.UpdatesTooltip { id: panel }
    }
    Support.NativeFocusDriver {
        id: driver
        onFailed: message => { console.error("SERVICES FAIL: updates panel " + message); Qt.quit() }
        onCompleted: {
            console.log("PASS: update group counts and colors, full-width global search, scroll reset, live refresh and empty results")
            Qt.quit()
        }
    }
    Component.onCompleted: {
        driver.waitFor("initial snapshot", () => UpdatesService.lastChecked.getTime() > 0)
        driver.add("populate groups", () => root.refresh(root.snapshot()))
        driver.waitFor("colored group dividers", () => UpdatesService.count === 67
            && root.label('Priority').text === '2'
            && root.label('Other').text === '65', () => {
            driver.check(root.label('Priority').color === Theme.warning && root.rows('Priority').every(row => row.nameColor === root.label('Priority').color), 'priority count matches package name color')
            driver.check(root.label('Other').color === Theme.text && root.rows('Other').every(row => row.nameColor === root.label('Other').color), 'other count matches package name color')
        })
        driver.waitFor("right-aligned counts", () => ['Priority','Other'].every(name => {
            const count = root.label(name), section = root.section(name)
            return section.width > 0 && Math.abs(count.mapToItem(section,count.width,0).x - section.width) < 1
        }))
        driver.waitFor("search layout", () => root.find('updatesSearch').width === panel.width
            && root.find('updatesSearch').mapToItem(panel,0,0).y > 0, () => {
            const search = root.find('updatesSearch') as UI.SearchField
            const checked = root.find('updatesLastChecked') as UI.ColumnText
            driver.check(search.mapToItem(panel,0,0).y >= checked.mapToItem(panel,0,checked.height).y, 'search is below last checked and spans the header')
            const list = root.find('updatesList') as Flickable
            driver.check(list.contentHeight > list.height && panel.height <= panel.maxPanelHeight, 'long update list stays within panel height')
            list.contentY = 40
            panel.searchText = '  LiNuX  '
        })
        driver.waitFor("case-insensitive package search", () => panel.priorityUpdates.length === 1 && panel.normalUpdates.length === 0, () => {
            driver.check(root.label('Priority').text === '1' && !root.section('Other').visible, 'filtered counts omit empty groups')
            driver.check((root.find('updatesList') as Flickable).contentY === 0, 'filter resets scrolling')
        })
        driver.add("repository search", () => panel.searchText = 'aur')
        driver.waitFor("repository matches other group", () => panel.priorityUpdates.length === 0 && panel.normalUpdates.length === 1)
        driver.add("search both groups by version", () => panel.searchText = '2.0')
        driver.waitFor("global version matches", () => panel.priorityUpdates.length === 1 && panel.normalUpdates.length === 1, () => {
            driver.check(UpdatesService.count === 67 && root.label('Other').text === '1', 'search preserves available total and updates both group counts')
        })
        driver.add("clear search", () => {
            const button = driver.find(root.find('updatesSearch'), 'clearSearch') as UI.ActionButton
            driver.click(button, button.width / 2, button.height / 2)
        })
        driver.waitFor("clear restores both groups", () => panel.priorityUpdates.length === 2 && panel.normalUpdates.length === 65)
        driver.add("no matches", () => panel.searchText = 'missing-package')
        driver.waitFor("empty search results", () => root.find('updatesNoResults').visible, () => {
            driver.check(!root.section('Priority').visible && !root.section('Other').visible, 'no orphan section dividers')
        })
        driver.add("refresh while filtering", () => {
            panel.searchText = 'example'
            root.refresh('core x86_64 linux 1.0 2.0\nextra x86_64 example 2.0 3.0\n')
        })
        driver.waitFor("filter survives refresh", () => UpdatesService.count === 2 && panel.normalUpdates.length === 1, () => {
            driver.check(panel.searchText === 'example' && panel.normalUpdates[0].newVersion === '3.0', 'latest snapshot retains the search')
        })
        driver.add("no available updates", () => root.refresh(''))
        driver.waitFor("empty successful snapshot", () => UpdatesService.count === 0, () => {
            driver.check(!root.find('updatesNoResults').visible && !root.section('Priority').visible && !root.section('Other').visible, 'empty cache does not show filtered no-results state')
        })
        driver.running = true
    }
}
