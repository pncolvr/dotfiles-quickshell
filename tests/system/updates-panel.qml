pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../src/modules/updates" as Updates
import "../../src/ui" as UI
import "../../src/theme"
import "../../src/config"
import "../../src/services"
import "../launcher" as Support

WorkerScope {
    id: root
    property var settings: Config
    function find(name) { return driver.find(panel, name) }
    function section(name) { return find("updates" + name + "Section") }
    function label(name) { return find("updates" + name + "SectionCount") as UI.ColumnText }
    function rows(name) { return (section(name) as Updates.UpdateSection).contentItem.children.filter(item => item instanceof Updates.UpdateRow) }
    function toggle(name) {
        const button = find("updates" + name + "SectionToggle")
        driver.click(button, button.width / 2, button.height / 2)
    }
    function nearWidth(a, b) { return Math.abs(a - b) < 0.1 }
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
            console.log("PASS: collapsible update defaults and toggles, search reveal and restoration, colored counts, scroll reset, live refresh and empty results")
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
            driver.check(root.rows('Priority').length === 2 && root.rows('Other').length === 65,
                'shared content slot contains every update row')
            for (const name of ['Priority', 'Other']) {
                const heading = root.find('updates' + name + 'SectionToggle') as UI.CollapsibleSection
                const arrow = driver.find(heading, 'collapsibleChevron') as UI.IconText
                driver.check(arrow.color === Theme.text, name + ' chevron uses normal text color independently of its count')
            }
        })
        driver.waitFor("right-aligned counts", () => ['Priority','Other'].every(name => {
            const count = root.label(name), section = root.section(name)
            return section.width > 0 && Math.abs(count.mapToItem(section,count.width,0).x - section.width) < 1
        }))
        driver.add("scrollbar uses existing outer padding", () => {
            const list = root.find('updatesList') as Flickable
            const bar = list.children.find(item => item instanceof UI.ScrollBar)
            driver.check(root.nearWidth(list.width - panel.width, Theme.scrollbarGutter)
                && root.section('Priority').width === panel.width && root.section('Other').width === panel.width,
                'versions and counts keep their original content width')
            driver.check(list.width - Theme.scrollbarHoverWidth >= panel.width
                && list.width <= panel.width + Theme.tooltipPaddingWidth
                && bar.width <= Theme.scrollbarHoverWidth,
                'full scrollbar growth fits in the existing panel padding')
        })
        driver.add("initial collapse defaults", () => {
            driver.check(root.section('Priority').showingContent && !root.section('Other').showingContent,
                'priority starts expanded and other starts collapsed')
            driver.check(['Priority','Other'].every(name => {
                const heading = root.find('updates' + name + 'SectionToggle') as UI.CollapsibleSection
                return heading.contentItem.children.filter(item => item instanceof UI.ColumnText).length === 1
            }),
                'update dividers have no visible section names')
            const other = root.section('Other'), button = root.find('updatesOtherSectionToggle')
            driver.check(other.height === button.height && root.section('Priority').height > button.height,
                'collapsed groups reserve only their divider height')
            driver.check(!root.section('Other').contentItem.visible && root.section('Priority').contentItem.visible,
                'collapsed rows are hidden while both counts remain visible')
            root.toggle('Priority')
        })
        driver.waitFor("collapse priority", () => !root.section('Priority').showingContent, () => root.toggle('Priority'))
        driver.waitFor("reopen priority", () => root.section('Priority').showingContent, () => root.toggle('Other'))
        driver.waitFor("open other", () => root.section('Other').showingContent
            && (root.find('updatesList') as Flickable).contentHeight > (root.find('updatesList') as Flickable).height)
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
        driver.add("restore full list before collapsing", () => panel.searchText = '')
        driver.waitFor("full list restored", () => panel.normalUpdates.length === 65, () => root.toggle('Other'))
        driver.waitFor("other collapsed manually", () => !root.section('Other').showingContent, () => root.toggle('Priority'))
        driver.waitFor("both collapsed manually", () => !root.section('Priority').showingContent, () => panel.searchText = 'aur')
        driver.waitFor("repository matches other group", () => panel.priorityUpdates.length === 0 && panel.normalUpdates.length === 1, () => {
            driver.check(root.section('Other').showingContent && !root.section('Other').expanded,
                'search reveals collapsed matches without changing manual state')
        })
        driver.add("search both groups by version", () => panel.searchText = '2.0')
        driver.waitFor("global version matches", () => panel.priorityUpdates.length === 1 && panel.normalUpdates.length === 1, () => {
            driver.check(UpdatesService.count === 67 && root.label('Other').text === '1', 'search preserves available total and updates both group counts')
        })
        driver.add("matching sections stay open during search", () => root.toggle('Priority'))
        driver.add("forced expansion preserves manual state", () => {
            driver.check(root.section('Priority').showingContent && !root.section('Priority').expanded,
                'search keeps matching rows visible without overwriting manual choices')
        })
        driver.add("clear search", () => {
            const button = driver.find(root.find('updatesSearch'), 'clearSearch') as UI.ActionButton
            driver.click(button, button.width / 2, button.height / 2)
        })
        driver.waitFor("clear restores both groups", () => panel.priorityUpdates.length === 2 && panel.normalUpdates.length === 65, () => {
            driver.check(!root.section('Priority').showingContent && !root.section('Other').showingContent,
                'clearing search restores both manually collapsed sections')
        })
        driver.add("keyboard expands a section", () => {
            const button = root.find('updatesOtherSectionToggle') as UI.CollapsibleSection
            button.forceActiveFocus(Qt.TabFocusReason)
            driver.key(Qt.Key_Space)
        })
        driver.waitFor("keyboard expansion", () => root.section('Other').showingContent, () => driver.key(Qt.Key_Space))
        driver.waitFor("keyboard collapse", () => !root.section('Other').showingContent)
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
            driver.check(root.find('updatesSearch').visible, 'search remains available with two updates')
        })
        driver.add("only priority updates available", () => {
            root.refresh('core x86_64 linux 1.0 2.0')
        })
        driver.waitFor("empty other group hidden without search", () => UpdatesService.count === 1
            && panel.priorityUpdates.length === 1 && !panel.normalUpdates.length, () => {
            driver.check(root.section('Priority').visible && !root.section('Other').visible
                && !root.label('Other').visible && !root.find('updatesOtherSectionToggle').visible,
                'empty other snapshot hides the entire section, count and toggle')
            driver.check(!root.find('updatesSearch').visible && panel.searchText === '',
                'one update hides search and clears its previous filter')
        })
        driver.add("only other updates available", () => root.refresh('extra x86_64 example 2.0 3.0'))
        driver.waitFor("empty priority group hidden without search", () => UpdatesService.count === 1
            && !panel.priorityUpdates.length && panel.normalUpdates.length === 1, () => {
            driver.check(root.section('Other').visible && !root.section('Priority').visible
                && !root.label('Priority').visible && !root.find('updatesPrioritySectionToggle').visible,
                'empty priority snapshot hides the entire section, count and toggle')
        })
        driver.add("no available updates", () => root.refresh(''))
        driver.waitFor("empty successful snapshot", () => UpdatesService.count === 0, () => {
            driver.check(!root.find('updatesNoResults').visible && !root.section('Priority').visible && !root.section('Other').visible, 'empty cache does not show filtered no-results state')
            driver.check(!root.find('updatesSearch').visible, 'no updates hides search')
        })
        driver.running = true
    }
}
