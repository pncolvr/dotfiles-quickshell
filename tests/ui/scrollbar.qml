pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/ui" as UI
import "../../src/theme"
import "../../src/config"
import "../../src/services"
import "../launcher" as Support

WorkerScope {
    id: root
    property var settings: Config
    property var audio: AudioService
    property var touchSequence: null
    property real fullWidth: 0
    property bool trackGrowth: false
    property int growthFrames: 0
    FrameAnimation {
        running: root.trackGrowth
        onTriggered: {
            try {
                driver.check(root.near(verticalBar.x + verticalBar.width / 2, vertical.width - Theme.scrollbarGutter / 2),
                    'vertical thumb center stays fixed on every animation frame')
                driver.check(root.near(horizontalBar.y + horizontalBar.height / 2, horizontal.height - Theme.scrollbarGutter / 2),
                    'horizontal thumb center stays fixed on every animation frame')
                if (verticalBar.width > Theme.scrollbarWidth + 0.1 && verticalBar.width < Theme.scrollbarHoverWidth - 0.1) root.growthFrames++
            } catch (error) {
                root.trackGrowth = false
                driver.running = false
                driver.failed(String(error))
            }
        }
    }
    Test.TestEvent { id: events }
    Test.TestResult { id: objects }
    function near(a, b) { return Math.abs(a - b) < 0.1 }
    function move(item, x, y, buttons = Qt.NoButton) {
        driver.check(events.mouseMove(item, x, y, 0, buttons, Qt.NoModifier), "pointer event delivered")
    }
    function wheel(view, dx, dy, modifiers = Qt.NoModifier) {
        driver.check(events.mouseWheel(view, 50, 50, Qt.NoButton, modifiers, dx, dy, 0), 'wheel event delivered')
    }
    function park() { move(canvas, 670, 700) }
    function barFor(view, direction) { return view.children.find(item => item instanceof UI.ScrollBar && item.orientation === direction) }
    readonly property UI.ScrollBar listBar: barFor(list, Qt.Vertical)
    function fieldScroll() { return field.children.find(item => item instanceof QC.ScrollView) }
    function grip(bar) { return objects.findChild(bar, "scrollbarGrip") as HoverHandler }
    QtObject {
        id: pickerState
        property string layout: "list"
        property var filteredItems: Array.from({length: 20}, (_, i) => ({id: String(i), title: 'Entry ' + i}))
        property int currentIndex: 0
        property int mode: PickerService.Mode.Webapps
        property var selectedIds: []
        property bool multiple: false
        property bool searchPending: false
        property bool searchFailed: false
        function select(index, toggle) { currentIndex = index }
        function accept(first, second) {}
    }
    FloatingWindow {
        visible: true
        implicitWidth: 700
        implicitHeight: 720
        Item {
            id: canvas
            anchors.fill: parent
            Flickable {
                id: vertical
                property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: vertical }
                x: 20; y: 20; width: 160 + Theme.scrollbarGutter; height: 120
                contentWidth: width; contentHeight: 20000
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Rectangle { id: verticalContent; width: 160; height: 20000; color: Theme.alternateBackground }
                QC.ScrollBar.vertical: UI.ScrollBar { id: verticalBar }
            }
            UI.SelectionList {
                id: list
                x: 210; y: 20; width: 160; height: 120
                options: Array.from({length: 50}, (_, i) => ({name: String(i), description: 'Option ' + i}))
            }
            QC.ScrollView {
                id: scroll
                property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: scroll.contentItem as Flickable }
                x: 20; y: 180; width: 160; height: 120
                padding: 0
                leftPadding: Theme.scrollbarGutter
                rightPadding: Theme.scrollbarGutter
                contentWidth: availableWidth; contentHeight: 1000
                clip: true
                Rectangle { id: scrollBody; width: scroll.availableWidth; height: 1000; color: Theme.alternateBackground }
                QC.ScrollBar.horizontal: UI.ScrollBar { policy: QC.ScrollBar.AlwaysOff }
                QC.ScrollBar.vertical: UI.ScrollBar { id: scrollBar }
            }
            UI.LineListField {
                id: field
                x: 210; y: 180; width: 160
                label: "Multiline"
                text: Array.from({length: 30}, (_, i) => 'Folder ' + i).join('\n')
            }
            Flickable {
                id: horizontal
                property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: horizontal }
                x: 20; y: 360; width: 160; height: 70
                contentWidth: 20000; contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Rectangle { y: Theme.scrollbarGutter; width: 20000; height: horizontal.height - Theme.scrollbarGutter * 2; color: Theme.alternateBackground }
                QC.ScrollBar.horizontal: UI.ScrollBar { id: horizontalBar }
            }
            UI.TabBar {
                id: tabs
                x: 210; y: 370; width: 160
                labels: ['First long window title', 'Second long window title', 'Third long window title']
            }
            Flickable {
                id: outerScroll
                x: 210; y: 430; width: 160; height: 120
                contentWidth: width; contentHeight: 600
                clip: true
                property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: outerScroll }
                Flickable {
                    id: innerScroll
                    x: 20; y: 10; width: 100; height: 90
                    contentWidth: width; contentHeight: 600
                    clip: true
                    property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: innerScroll }
                    Rectangle { width: innerScroll.width; height: 600; color: Theme.alternateBackground }
                }
            }
            UI.PickerList {
                id: pickerList
                x: 410; y: 430; width: 260; height: 240
                picker: pickerState
            }
            UI.ManagementView {
                id: manage
                x: 410; y: 20; width: 260; height: 400
                entries: [{id: 'one', title: 'One', subtitle: ''}]
                selectedId: 'one'
                detailContent: Rectangle { width: parent.width; height: 1000; color: Theme.alternateBackground }
            }
        }
    }
    Support.NativeFocusDriver {
        id: driver
        timeout: 2000
        onFailed: message => { console.error('SCROLLBAR FAIL:', message); Qt.quit() }
        onCompleted: {
            console.log('PASS: shared scrollbar viewport hover, centered growth, grab cursors, vertical/horizontal dragging, fade, navigation, overflow policy and motion gating')
            console.log('PASS: shared scroll input disables mouse/touch flicks while preserving wheels, bounds, navigation and scrollbar dragging')
            console.log('PASS: shared scrollbar ScrollView, multiline fields and management details reserve balanced padding without covering content')
            Qt.quit()
        }
    }
    Component.onCompleted: {
        driver.add('park outside scroll areas', root.park)
        driver.waitFor('overflow geometry', () => verticalBar.needed && listBar.needed && scrollBar.needed && horizontalBar.needed
            && root.barFor(root.fieldScroll(), Qt.Vertical)?.needed === true
            && tabs.contentWidth > tabs.width)
        driver.waitFor('idle bars fade', () => verticalBar.contentItem.opacity === 0)
        driver.add('consistent base style', () => {
            for (const bar of [verticalBar, listBar, scrollBar, horizontalBar]) {
                driver.check(root.near(bar.thickness, 6) && bar.contentItem.color === Theme.accent
                    && bar.background === null && bar.scrollHost !== null, 'shared geometry, palette and scroll host')
                driver.check(root.grip(bar).cursorShape === Qt.OpenHandCursor, 'open hand before dragging')
                driver.check(bar.contentItem.radius === Theme.scrollbarWidth / 2, 'thin thumb keeps rounded ends')
            }
            driver.check(verticalBar.contentItem.height >= 24 && horizontalBar.contentItem.width >= 24, 'long lists retain grabbable minimum thumb lengths')
            const details = manage.detailScroll.contentItem.children.find(item => item instanceof Column)
            driver.check(details.x === Theme.scrollbarGutter && details.width + Theme.scrollbarGutter * 2 === manage.detailScroll.width,
                'nested management details reserve equal left and right padding')
            const row = manage.listView.currentItem
            driver.check(row.leftPadding === row.rightPadding && row.rightPadding >= Theme.scrollbarGutter,
                'nested management rows keep text clear with equal padding')
            driver.check(list.currentItem.leftPadding === list.currentItem.rightPadding
                && list.currentItem.rightPadding >= Theme.scrollbarGutter,
                'dropdown choices reserve equal side padding')
            root.trackGrowth = true
            root.move(vertical, 50, 50)
        })
        driver.waitFor('viewport hover reveals thin thumb', () => verticalBar.contentItem.opacity === 1, () => {
            driver.check(!verticalBar.hovered && verticalBar.width === 6, 'hovering content reveals without widening')
            root.move(verticalBar, verticalBar.width / 2, 10)
        })
        driver.waitFor('vertical hover grows around a fixed center', () => verticalBar.width === Theme.scrollbarHoverWidth, () => {
            driver.check(root.near(verticalBar.x + verticalBar.width / 2, vertical.width - Theme.scrollbarGutter / 2) && vertical.contentWidth === vertical.width,
                'growth stays centered in padding without resizing content')
            driver.check(verticalBar.x > verticalContent.width, 'grown thumb fits entirely in existing panel padding')
            driver.check(verticalBar.contentItem.radius === Theme.scrollbarWidth / 2
                && verticalBar.contentItem.radius < verticalBar.width / 2, 'expanded thumb has squarer corners')
            driver.check(events.mousePress(verticalBar, verticalBar.width / 2, 10, Qt.LeftButton, Qt.NoModifier, 0), 'press thumb')
        })
        driver.waitFor('closed hand while grabbed', () => verticalBar.pressed, () => {
            driver.check(root.grip(verticalBar).cursorShape === Qt.ClosedHandCursor, 'closed hand while dragging')
            root.move(verticalBar, verticalBar.width / 2, verticalBar.height - 10, Qt.LeftButton)
        })
        driver.waitFor('drag scrolls vertically', () => vertical.contentY > 0, () => root.move(canvas, 670, 700, Qt.LeftButton))
        driver.add('drag remains wide outside viewport', () => {
            driver.check(verticalBar.pressed && root.near(verticalBar.width, Theme.scrollbarHoverWidth), 'grab survives pointer leaving')
            driver.check(events.mouseRelease(canvas, 670, 700, Qt.LeftButton, Qt.NoModifier, 0), 'release thumb')
        })
        driver.waitFor('release shrinks and fades', () => !verticalBar.pressed && root.near(verticalBar.width, 6)
            && verticalBar.contentItem.opacity === 0)
        driver.add('programmatic navigation reveals thumb', () => vertical.contentY = 100)
        driver.waitFor('navigation activity', () => verticalBar.contentItem.opacity === 1)
        driver.waitFor('navigation settles', () => verticalBar.contentItem.opacity === 0)
        driver.add('horizontal grip hover', () => root.move(horizontalBar, 10, horizontalBar.height / 2))
        driver.waitFor('horizontal hover grows around a fixed center', () => root.near(horizontalBar.height, Theme.scrollbarHoverWidth), () => {
            driver.check(root.near(horizontalBar.y + horizontalBar.height / 2, horizontal.height - Theme.scrollbarGutter / 2), 'horizontal growth retains gutter center')
            driver.check(events.mousePress(horizontalBar, 10, horizontalBar.height / 2, Qt.LeftButton, Qt.NoModifier, 0), 'press horizontal thumb')
            root.move(horizontalBar, horizontalBar.width - 10, horizontalBar.height / 2, Qt.LeftButton)
        })
        driver.waitFor('drag scrolls horizontally', () => horizontal.contentX > 0, () => {
            driver.check(events.mouseRelease(horizontalBar, horizontalBar.width - 10, horizontalBar.height / 2, Qt.LeftButton, Qt.NoModifier, 0), 'release horizontal thumb')
            root.park()
        })
        driver.add('ScrollView hover', () => root.move(scroll, 50, 50))
        driver.waitFor('ScrollView uses viewport hover', () => scrollBar.contentItem.opacity === 1, () => {
            driver.check(scroll.availableWidth + Theme.scrollbarGutter * 2 === scroll.width, 'ScrollView reserves equal left and right padding')
            root.move(scrollBar, scrollBar.width / 2, 10)
        })
        driver.waitFor('ScrollView grip grows', () => root.near(scrollBar.width, Theme.scrollbarHoverWidth), () => {
            driver.check(scroll.availableWidth + Theme.scrollbarGutter * 2 === scroll.width && scroll.contentWidth === scroll.availableWidth, 'ScrollView content clearance survives growth')
            root.park()
            list.positionViewAtIndex(40, ListView.Contain)
        })
        driver.waitFor('list navigation reveals thumb', () => listBar.contentItem.opacity === 1)
        driver.add('multiline field hover', () => {
            root.fullWidth = root.fieldScroll().availableWidth
            const bar = root.barFor(root.fieldScroll(), Qt.Vertical)
            root.move(bar, bar.width / 2, 10)
        })
        driver.waitFor('multiline scrollbar grows without reflow', () => root.near(root.barFor(root.fieldScroll(), Qt.Vertical).width, Theme.scrollbarHoverWidth), () => {
            driver.check(root.fullWidth + Theme.scrollbarGutter * 2 === field.width && root.fieldScroll().availableWidth === root.fullWidth,
                'multiline field keeps balanced padding without reflow')
            driver.check(root.near(scrollBody.mapToItem(scroll, 0, 0).x, scroll.leftPadding)
                && root.fieldScroll().leftPadding === root.fieldScroll().rightPadding,
                'editor content sits between equal side margins')
            driver.check(root.growthFrames > 0, 'centering checked during animated intermediate widths')
            root.trackGrowth = false
            root.park()
            vertical.contentHeight = 80
        })
        driver.waitFor('fitting content hides scrollbar', () => !verticalBar.visible)
        driver.add('disabled axis policy', () => { horizontalBar.policy = QC.ScrollBar.AlwaysOff; root.move(horizontal, 50, 30) })
        driver.add('AlwaysOff stays hidden on viewport hover', () => {
            driver.check(!horizontalBar.visible, 'disabled axis follows shared visibility policy')
            root.park()
            vertical.contentHeight = 20000
            root.settings.animationsEnabled = false
        })
        driver.waitFor('restore overflow', () => verticalBar.visible)
        driver.add('picker list has balanced side padding', () => {
            driver.check(root.near(pickerList.currentItem.mapToItem(pickerList, 0, 0).x, Theme.scrollbarGutter)
                && pickerList.currentItem.width === pickerList.width - Theme.scrollbarGutter * 2,
                'vertical picker rows have equal side margins')
            pickerState.layout = 'grid'
        })
        driver.waitFor('picker switches to horizontal layout', () => pickerList.orientation === ListView.Horizontal
            && root.near(pickerList.currentItem.mapToItem(pickerList, 0, 0).y, Theme.scrollbarGutter), () => {
            driver.check(pickerList.currentItem.height === pickerList.height - Theme.scrollbarGutter * 2,
                'horizontal picker cards have equal top and bottom margins')
            driver.check(root.near(pickerList.currentItem.mapToItem(pickerList, 0, 0).x, 0),
                'horizontal layout starts without a stale vertical side offset')
            pickerList.width = 600
            pickerState.filteredItems = pickerState.filteredItems.slice(0, 5)
        })
        driver.waitFor('fitting grid reclaims scrollbar padding', () => pickerList.contentWidth <= pickerList.width
            && root.near(pickerList.currentItem.mapToItem(pickerList, 0, 0).y, 0), () => {
            driver.check(pickerList.currentItem.height === pickerList.height
                && !root.barFor(pickerList, Qt.Horizontal).visible,
                'fitting grid tiles use the full height without an empty scrollbar strip')
            pickerList.width = 260
        })
        driver.waitFor('overflow restores horizontal padding', () => pickerList.contentWidth > pickerList.width
            && root.near(pickerList.currentItem.mapToItem(pickerList, 0, 0).y, Theme.scrollbarGutter), () => {
            driver.check(pickerList.currentItem.height === pickerList.height - Theme.scrollbarGutter * 2,
                'overflowing grids reserve space around their scrollbar again')
            pickerState.layout = 'list'
        })
        driver.waitFor('picker restores vertical margins', () => pickerList.orientation === ListView.Vertical
            && root.near(pickerList.currentItem.mapToItem(pickerList, 0, 0).x, Theme.scrollbarGutter), () => {
            driver.check(root.near(pickerList.currentItem.mapToItem(pickerList, 0, 0).y, 0),
                'vertical layout starts without a stale horizontal side offset')
        })
        driver.add('all scroll viewports disable content gestures', () => {
            for (const view of [vertical, horizontal, list, scrollBar.scrollHost,
                root.barFor(root.fieldScroll(), Qt.Vertical).scrollHost, pickerList, manage.detailScroll]) {
                driver.check(!view.interactive, 'mouse and touch flicking disabled on raw, list and editor viewports')
            }
            vertical.contentY = 100
            root.wheel(vertical, 0, -120)
        })
        driver.waitFor('wheel scrolling works without flicking', () => vertical.contentY === 140, () => {
            driver.check(!vertical.flicking && !vertical.moving, 'wheel input changes position immediately without inertia')
            vertical.contentY = 0
            root.wheel(vertical, 0, 120)
            driver.check(vertical.contentY === 0, 'wheel clamps to the top')
            vertical.contentY = vertical.contentHeight - vertical.height
            root.wheel(vertical, 0, -120)
            driver.check(vertical.contentY === vertical.contentHeight - vertical.height, 'wheel clamps to the bottom')
            vertical.contentY = 100
            driver.check(events.mousePress(vertical, 50, 100, Qt.LeftButton, Qt.NoModifier, 0), 'press content')
        })
        driver.add('dragging content does not scroll', () => root.move(vertical, 50, 10, Qt.LeftButton))
        driver.add('content drag leaves its position unchanged', () => {
            driver.check(vertical.contentY === 100 && !vertical.dragging && !vertical.flicking, 'mouse drag never moves content')
            driver.check(events.mouseRelease(vertical, 50, 10, Qt.LeftButton, Qt.NoModifier, 0), 'release content')
            root.touchSequence = events.touchEvent(vertical)
            root.touchSequence.press(0, vertical, 50, 100).commit()
        })
        driver.add('touch swipe does not scroll', () => root.touchSequence.move(0, vertical, 50, 10).commit())
        driver.add('touch swipe leaves its position unchanged', () => {
            root.touchSequence.release(0, vertical, 50, 10).commit()
            driver.check(vertical.contentY === 100 && !vertical.dragging && !vertical.flicking, 'touch never drags or flings content')
            horizontal.contentX = 0
            root.wheel(horizontal, 0, -120)
        })
        driver.waitFor('vertical wheel scrolls a horizontal-only viewport', () => horizontal.contentX === 40, () => {
            root.wheel(horizontal, -120, 0)
            driver.check(horizontal.contentX === 80, 'horizontal wheel input works too')
            scrollBar.scrollHost.contentY = 0
            root.wheel(scroll, 0, -120)
        })
        driver.waitFor('ScrollView wheel input remains available', () => scrollBar.scrollHost.contentY === 40, () => {
            vertical.scrollBehavior.enabled = false
            root.wheel(vertical, 0, -120)
            driver.check(vertical.contentY === 100, 'disabled input policy blocks wheels without restoring flicking')
            vertical.scrollBehavior.enabled = true
            root.park()
        })
        driver.add('nested wheel scrolls the innermost viewport', () => {
            root.wheel(innerScroll, 0, -120)
            driver.check(innerScroll.contentY === 40 && outerScroll.contentY === 0, 'one wheel gesture scrolls only the inner view')
            innerScroll.contentY = innerScroll.contentHeight - innerScroll.height
            root.wheel(innerScroll, 0, -120)
        })
        driver.waitFor('nested boundary passes wheel input outward', () => outerScroll.contentY === 40)
        driver.add('motion disabled', () => {
            root.move(verticalBar, verticalBar.width / 2, 10)
            driver.check(root.near(verticalBar.width, Theme.scrollbarHoverWidth), 'disabled animations settle growth immediately')
            root.park()
            driver.check(root.near(verticalBar.width, 6), 'disabled animations settle shrink immediately')
            root.settings.animationsEnabled = true
            root.audio.screencastActive = true
            root.move(verticalBar, verticalBar.width / 2, 10)
            driver.check(root.near(verticalBar.width, Theme.scrollbarHoverWidth), 'screen sharing policy settles growth immediately')
            root.audio.screencastActive = false
            root.park()
        })
        driver.running = true
    }
}
