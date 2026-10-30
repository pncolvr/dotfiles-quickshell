pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/ui" as UI
import "../../src/theme"
import "../../src/services"
import "../../src/modules/system/stats" as Stats
import "../../src/modules/system/audio" as Audio
import "../../src/modules/media" as Media
import "../../src/modules/updates" as Updates
import "../../src/modules/system/timers" as Timers
import "../../src/ui/components/ButtonColors.mjs" as Colors
import "../launcher" as Support

WorkerScope {
    id: root
    property var palette: Theme
    property int clicks: 0
    function surface(button): UI.ButtonSurface { return button.background as UI.ButtonSurface }
    function move(item) { driver.check(events.mouseMove(item,item.width / 2,item.height / 2,0,Qt.NoButton,Qt.NoModifier), 'pointer delivery') }
    function park() { events.mouseMove(backdrop,backdrop.width - 5,backdrop.height - 5,0,Qt.NoButton,Qt.NoModifier) }
    function checkContrast(button) {
        const surface = root.surface(button)
        const actual = Colors.composite(surface.color,surface.surfaceColor)
        const expected = Colors.composite(surface.referenceColor,Theme.background)
        const matched = Math.abs(Colors.contrast(actual,surface.surfaceColor) - Colors.contrast(expected,Theme.background)) < 0.004
        const fallback = ['r','g','b'].every(key=>Math.abs(actual[key]-expected[key])<0.001)
        driver.check(matched || fallback, 'rendered hover retains theme contrast or its readable palette fallback')
    }
    Test.TestEvent { id: events }
    FloatingWindow {
        visible: true
        implicitWidth: 780; implicitHeight: 780
        color: Theme.background
        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: Theme.background
            Column {
                x:20; y:20; width:720; spacing:12
                Row {
                    spacing:12
                    UI.Button { id: plain; text:'Plain'; checkable:true; width:80; onClicked:root.clicks++ }
                    UI.ActionButton { id: action; fillColor:'transparent'; label:'Transparent'; glyph:Theme.refreshIcon; onClicked:root.clicks++ }
                    UI.CopyButton { id: copy; fillColor:'transparent'; feedbackDuration:20; copyAction:completed=>completed(true) }
                    UI.IconButton { id: icon; text:Theme.refreshIcon; iconColor:Theme.inactive }
                    Audio.AudioButton { id: audio; glyph:Theme.volumeMutedIcon }
                }
                UI.TabBar { id: tabs; width:600; labels:['One','Two'] }
                UI.CheckBox { id: checkBox; text:'Enabled' }
                UI.CollapsibleSection { id: disclosure; width:250; text:'Section'; onExpansionRequested: expanded=>disclosure.expanded=expanded; contentItem:UI.ColumnText{text:disclosure.text} }
                UI.ComboSelector { id: combo; width:300; compact:true; selectedName:'first'; options:[{name:'first',description:'First'},{name:'second',description:'Second'}] }
                UI.SelectionRow { id: option; width:300; description:'Option' }
                Stats.StatsOverview {
                    id: overview
                    width:360
                    statsService: ({cpu:2,memoryUsed:1024,memoryTotal:4096,temperature:42})
                    networkService: ({downloadSpeed:0,uploadSpeed:0,connectedNetworks:[],vpnConnections:[],formatSpeed:()=> '0 B'})
                    powerService: power
                }
            }
            Column {
                x:20; y:540; width:720; spacing:12
                Media.TwitchUserRow {
                    id: twitchRow
                    width: parent.width
                    user: ({login:'synthetic',online:true,game:'Game',title:'Synthetic stream',viewers:1,avatar:''})
                }
                Updates.UpdateRow {
                    id: updateRow
                    width: parent.width
                    update: ({name:'synthetic-package',oldVersion:'1.0',newVersion:'2.0'})
                    nameColor: Theme.warning
                }
                Timers.TimeEntryRow {
                    id: timerRow
                    width: parent.width
                    entry: ({title:'Synthetic timer',running:false,finished:false,valueMs:0,elapsedMs:0,urgency:0})
                }
            }
            Rectangle {
                id: tint
                x:450; y:220; width:270; height:60
                color: Qt.rgba(0.2,0.3,0.4,0.5)
                UI.ActionButton { id:nested; anchors.centerIn:parent; label:'Inside a card'; fillColor:'transparent'; foreground:Theme.accent }
            }
        }
    }
    QtObject {
        id: power
        property var availableProfiles:['power-saver','balanced','performance']
        property string profile:'balanced'
        function setProfile(value) { profile=value }
    }
    Support.NativeFocusDriver {
        id:driver
        onFailed: message=>{console.error('BUTTONS FAIL:',message);Qt.quit()}
        onCompleted:{console.log('PASS: shared button families, active-theme contrast, visible transparent hover/press, nested surfaces, disabled actions, transparent disclosures, row hover and power-profile feedback');Qt.quit()}
    }
    Component.onCompleted: {
        const twitchOpen = driver.find(twitchRow, "openTwitchUser_synthetic") as UI.Button
        const twitchEdit = driver.find(twitchRow, "editTwitchUser_synthetic") as UI.ActionButton
        const twitchRemove = driver.find(twitchRow, "removeTwitchUser_synthetic") as UI.ActionButton
        for (const button of [plain,action]) {
            for (const key of [Qt.Key_Return,Qt.Key_Enter,Qt.Key_Space]) {
                driver.add('keyboard button activation '+key,()=>{
                    button.forceActiveFocus(Qt.TabFocusReason)
                    const before=root.clicks, wasChecked=button.checked
                    driver.key(key)
                    driver.check(root.clicks===before+1,'each activation key clicks exactly once')
                    if (button.checkable) driver.check(button.checked!==wasChecked,'keyboard activation toggles checkable buttons')
                })
            }
        }
        for (const light of [false,true]) {
            driver.add('set active palette',()=>{ root.palette.darkMode=!light;backdrop.color=Theme.background;root.park() })
            driver.add('all button families use the common surface',()=>{
                const trigger=driver.find(combo,combo.toggleObjectName) as QC.Button
                for (const button of [plain,action,copy,icon,audio,checkBox,disclosure,trigger,option,tabs.itemAt(0),twitchOpen])
                    driver.check(!!root.surface(button),'button family shares its background and interaction policy')
                driver.check(disclosure.focusPolicy===Qt.StrongFocus && disclosure.activeFocusOnTab,
                    'collapsible sections participate in keyboard traversal')
            })
            driver.add('collapsed section stays transparent',()=>{
                root.park()
                driver.check(!disclosure.expanded && root.surface(disclosure).color.a===0,'collapsed headers stay transparent at rest')
                root.move(disclosure)
            })
            driver.waitFor('section hover remains visible',()=>disclosure.hovered,()=>{
                driver.check(root.surface(disclosure).color.a>0,'transparent headers still show shared hover feedback')
                driver.click(disclosure)
                root.park()
            })
            driver.waitFor('expanded section stays transparent',()=>disclosure.expanded && !disclosure.hovered,()=>{
                driver.check(root.surface(disclosure).color.a===0,'expanded headers also stay transparent at rest')
                disclosure.forceExpanded=true
                driver.check(root.surface(disclosure).color.a===0,'search expansion does not fill the header')
                disclosure.forceExpanded=false
                driver.click(disclosure)
                root.park()
            })
            driver.waitFor('collapse restores transparent header',()=>!disclosure.expanded && !disclosure.hovered)
            for (const row of [twitchRow,updateRow,timerRow]) {
                driver.add('row idle background',()=>{
                    root.park()
                    driver.check(row.color.a===0,'rows remain transparent at rest')
                    root.move(row)
                })
                driver.waitFor('row hover matches Recent Files',()=>Qt.colorEqual(row.color,Theme.alternateBackground),()=>{
                    driver.check(row.radius===Theme.iconButtonRadius,'rows share the Recent Files corner radius')
                    root.park()
                })
                driver.waitFor('row hover clears on exit',()=>row.color.a===0)
            }
            for (const color of [null,'#28384a','#b8ada1']) {
                driver.add('change actual background',()=>{backdrop.color=color ?? Theme.background;root.park()})
                driver.add('idle transparent fill',()=>driver.check(root.surface(action).color.a===0,'idle remains transparent'))
                driver.add('hover transparent action',()=>root.move(action))
                driver.waitFor('visible hover',()=>action.hovered,()=>{
                    driver.check(root.surface(action).color.a>0,'transparent actions get a visible hover surface')
                    root.checkContrast(action)
                    action.down=true
                    driver.check(!Qt.colorEqual(root.surface(action).color,root.surface(action).hoverColor)
                        || !Qt.colorEqual(root.surface(action).pressedColor,root.surface(action).hoverColor),'press has separate feedback')
                    root.checkContrast(action)
                    action.down=false
                    root.move(nested)
                })
                driver.waitFor('nested card hover',()=>nested.hovered,()=>{
                    const expected=Colors.composite(tint.color,backdrop.color)
                    driver.check(Math.abs(root.surface(nested).surfaceColor.r-expected.r)<0.001,'card alpha is composited against its parent')
                    root.checkContrast(nested)
                    driver.check(Qt.colorEqual(nested.foreground,Theme.accent) && Qt.colorEqual(icon.iconColor,Theme.inactive),'semantic icon colors are preserved')
                })
            }
            for (const fill of ['#000000','#ffffff']) {
                driver.add('hover extreme opaque fill',()=>{root.park();action.fillColor=fill;root.move(action)})
                driver.waitFor('opaque fill has hover feedback',()=>action.hovered,()=>{
                    driver.check(!Qt.colorEqual(root.surface(action).color,action.fillColor),'black and white fills also show hover feedback')
                    root.checkContrast(action)
                    action.fillColor='transparent'
                    root.park()
                })
            }
            driver.add('power profile idle backgrounds',()=>{
                backdrop.color=Theme.background
                root.park()
                for (const name of power.availableProfiles) {
                    const button=driver.find(overview,'statsPowerProfile-'+name) as UI.ActionButton
                    driver.check(!button.hovered && root.surface(button).color.a>0,'every profile has a visible idle fill')
                    driver.check(Qt.colorEqual(button.fillColor,button.checked ? Theme.selectionSelectedBackground : Theme.alternateBackground),'selected and inactive profile fills remain distinct')
                    driver.check(Qt.colorEqual(button.foreground,button.checked ? Theme.accent : Theme.inactive),'profile icon colors retain their semantic role')
                }
            })
            driver.add('power profile hover',()=>{backdrop.color=Theme.background;root.move(driver.find(overview,'statsPowerProfile-power-saver'))})
            driver.waitFor('inactive power profile feedback',()=>driver.find(overview,'statsPowerProfile-power-saver').hovered,()=>{
                const button=driver.find(overview,'statsPowerProfile-power-saver') as UI.ActionButton
                driver.check(button.fillColor.a>0 && !Qt.colorEqual(root.surface(button).color,button.fillColor),'real inactive power profile brightens its visible idle fill on hover')
                root.checkContrast(button)
                button.enabled=false
                driver.check(Qt.colorEqual(root.surface(button).referenceColor,button.fillColor),'disabled buttons retain idle fill without hover feedback')
                driver.click(button)
                driver.check(power.profile==='balanced','disabled profile cannot activate')
                button.enabled=true
                root.park()
            })
        }
        driver.add('Twitch row keyboard traversal',()=>{
            driver.check(twitchOpen.activeFocusOnTab && twitchEdit.activeFocusOnTab && twitchRemove.activeFocusOnTab,
                'open, edit and remove all participate in Tab traversal')
            twitchOpen.forceActiveFocus(Qt.TabFocusReason)
            driver.key(Qt.Key_Tab)
            driver.check(twitchEdit.activeFocus,'Tab moves from the stream link to Edit')
            driver.key(Qt.Key_Tab)
            driver.check(twitchRemove.activeFocus,'Tab moves from Edit to Delete')
        })
        driver.add('copy remains specialized',()=>driver.click(copy))
        driver.waitFor('copy feedback',()=>copy.copied,()=>driver.check(copy.glyph===Theme.checkIcon && Qt.colorEqual(copy.foreground,Theme.active),'copy still shows a green checkmark'))
        driver.running=true
    }
}
