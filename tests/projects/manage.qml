pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/theme"
import "../../src/services/launcher/Search.mjs" as Search

Scope {
    id: root
    property bool failed: false
    property int step: 0
    property int ticks: 0
    property real savedPosition: 0
    property real workspacePosition: 0
    readonly property string projectPath: "/fixture/repos/p60"
    readonly property string workspacePath: projectPath + "/Finance.code-workspace"
    Test.TestEvent { id: events }
    FloatingWindow {
        visible: true
        implicitWidth: Theme.pickerWidth
        implicitHeight: Math.min(panel.implicitHeight,650)
        ProjectPickerPanel { id: panel; width: parent.width; height: parent.height }
    }
    function find(name,item=panel) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const result = find(name,child); if (result) return result }
        return null
    }
    function check(ok,message) { if (!ok) { failed = true; console.error("MANAGE FAIL:",message) } }
    function highlighted(text,query,fuzzy=true) { return Search.highlight(text,Search.searchPattern(query,true),fuzzy,"#abcdef") }
    function plain(text) { return text.replace(/<font[^>]*>|<\/font>/g,"") }
    function checkFooter(editing) {
        const hints = find("projectManageHints"), add = find("beginAddProjectSource")
        const center = item => item.mapToItem(panel,0,item.height / 2).y
        check(hints.lineCount === 1 && Math.abs(center(hints) - center(add)) < 1,"Manage hints and Add share one line")
        check(add.visible && add.enabled === !editing,"Add stays visible and is disabled while editing")
        if (editing) {
            const cancel = find("cancelProjectDraft"), apply = find("saveProjectDraft")
            check(Math.abs(center(cancel) - center(add)) < 1 && Math.abs(center(apply) - center(add)) < 1,
                "editor actions share the footer line")
            check(add.mapToItem(panel,add.width,0).x < cancel.mapToItem(panel,0,0).x
                && cancel.mapToItem(panel,cancel.width,0).x < apply.mapToItem(panel,0,0).x,"Cancel and Apply follow Add")
        }
    }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (++root.ticks > 250 || root.failed) { console.error("MANAGE FAIL: timeout step=" + root.step); stop(); Qt.quit(); return }
            if (!DbService.ready || ProjectService.busy) return
            const scroll = root.find("projectManageScroll").contentItem
            const search = root.find("projectManageSearch")
            switch (root.step++) {
            case 0:
                root.check(root.highlighted("q---quickshell","qsh") === 'q---<font color="#abcdef">q</font>uick<font color="#abcdef">sh</font>ell',"fuzzy highlighting uses the compact match preferred by the scorer")
                root.check(root.highlighted("Banana","ana",false) === 'B<font color="#abcdef">ana</font>na',"substring highlighting")
                root.check(root.highlighted("Foo foo","Foo") === '<font color="#abcdef">Foo</font> foo',"smart-case highlighting")
                root.check(root.highlighted("İstanbul","st",false) === 'İ<font color="#abcdef">st</font>anbul',"case folding preserves original character offsets")
                root.check(root.highlighted("İstanbul","sbl") === 'İ<font color="#abcdef">s</font>tan<font color="#abcdef">b</font>u<font color="#abcdef">l</font>',"fuzzy case folding preserves offsets and handles the last character")
                root.check(root.highlighted('<A&B> "😀"',"&",false) === '&lt;A<font color="#abcdef">&amp;</font>B&gt; &quot;😀&quot;',"names escape markup and preserve Unicode")
                root.check(root.highlighted("Banana","missing") === "Banana", "unmatched terms stay uncolored")
                root.check(DbService.write(tx => {
                    tx.executeSql("INSERT INTO store.project_sources(path,kind,category) VALUES('/fixture/repos','root','personal')")
                    for (let index = 0; index < 80; index++) {
                        const suffix = String(index).padStart(2,"0")
                        tx.executeSql("INSERT INTO store.projects(source_path,path,name,remote_url) VALUES(?,?,?,?)",
                            ["/fixture/repos","/fixture/repos/p" + suffix,index === 79 ? "<A&B>" : "Project " + suffix,""])
                    }
                    tx.executeSql("INSERT INTO store.project_workspaces VALUES(?,?,?,1)",[root.projectPath,root.workspacePath,"Finance"])
                    for (let index = 0; index < 40; index++) tx.executeSql("INSERT INTO store.project_workspaces VALUES(?,?,?,1)",
                        [root.projectPath,root.projectPath + "/Choice-" + index + ".code-workspace","Choice " + index])
                    tx.executeSql("INSERT INTO store.project_sources(path,kind,category) VALUES('/fixture/single','folder','personal')")
                    tx.executeSql("INSERT INTO store.projects(source_path,path,name,remote_url) VALUES('/fixture/single','/fixture/single','Standalone','')")
                    tx.executeSql("INSERT INTO store.project_workspaces VALUES('/fixture/single','/fixture/single/Solo.code-workspace','SoloWorkspace',1)")
                }),"seed a long synthetic project list")
                ProjectRepository.reload(); PickerService.projects(); ProjectService.setManaging(true)
                search.text = "pr60"
                break
            case 1:
                root.checkFooter(false)
                root.check(root.find("managedProjectName_" + root.projectPath).text.includes('<font color="' + Theme.accent + '">Pr</font>')
                    && root.plain(root.find("managedProjectName_" + root.projectPath).text) === "Project 60", "project name matches use the accent without altering text")
                search.text = "/p60"
                break
            case 2:
                root.check(root.find("managedProjectPath_" + root.projectPath).visible
                    && root.find("managedProjectPath_" + root.projectPath).text.includes("<font"),"path-only matches are visible and highlighted")
                search.text = "Finance"
                break
            case 3:
                root.check(!!root.find("managedProject_" + root.projectPath) && !!root.find("matchedWorkspace_" + root.workspacePath)
                    && root.find("matchedWorkspace_" + root.workspacePath).text.includes("<font"),"workspace search keeps the owning project and shows its match")
                search.text = "pr60 Finance"
                root.step = 31
                break
            case 31:
                root.check(!!root.find("managedProject_" + root.projectPath) && !!root.find("matchedWorkspace_" + root.workspacePath),
                    "multi-term searches highlight matches across repository and workspace fields")
                root.find("editProject_" + root.projectPath).clicked()
                root.step = 4
                break
            case 4:
                root.checkFooter(true)
                root.check(root.find("managedWorkspace_" + root.workspacePath).text.includes("<font"),"workspace edit labels retain match highlighting")
                const workspaceScroll = root.find("projectWorkspaceScroll").contentItem
                workspaceScroll.contentY = workspaceScroll.contentHeight - workspaceScroll.height - 10
                root.workspacePosition = workspaceScroll.contentY
                root.check(root.workspacePosition > 100,"workspace fixture can scroll")
                root.find("projectWorkspace_" + root.workspacePath).clicked()
                root.step = 41
                break
            case 41:
                root.check(Math.abs(root.find("projectWorkspaceScroll").contentItem.contentY - root.workspacePosition) < 1,
                    "toggling workspace inclusion preserves editor scroll")
                root.find("cancelProjectDraft").clicked(); search.clear()
                root.step = 5
                break
            case 5:
                scroll.contentY = scroll.contentHeight - scroll.height - 10
                root.savedPosition = scroll.contentY
                root.check(root.savedPosition > 100,"fixture has a scrolled list")
                root.find("editProject_" + root.projectPath).clicked()
                break
            case 6:
                root.check(Math.abs(scroll.contentY - root.savedPosition) < 1,"opening workspace edit preserves scroll")
                root.find("cancelProjectDraft").clicked()
                break
            case 7:
                root.check(Math.abs(scroll.contentY - root.savedPosition) < 1,"cancel and search refocus preserve scroll")
                root.find("editSource_/fixture/repos").clicked()
                break
            case 8:
                root.check(Math.abs(scroll.contentY - root.savedPosition) < 1,"opening source edit preserves scroll")
                root.find("cancelProjectDraft").clicked()
                break
            case 9:
                root.check(Math.abs(scroll.contentY - root.savedPosition) < 1,"source cancel preserves scroll")
                root.find("editProject_" + root.projectPath).clicked()
                break
            case 10:
                root.find("saveProjectDraft").clicked()
                break
            case 11:
                root.check(!ProjectService.draft && Math.abs(scroll.contentY - root.savedPosition) < 1,"saving and reloading keep scroll")
                root.find("editProject_" + root.projectPath).clicked()
                break
            case 12:
                root.find("projectManageSearch").forceActiveFocus()
                root.check(events.keyClick(Qt.Key_Escape,Qt.NoModifier,0),"Escape reaches editor")
                break
            case 13:
                root.check(!ProjectService.draft && Math.abs(scroll.contentY - root.savedPosition) < 1,"Escape cancellation preserves scroll")
                search.text = "&"
                break
            case 14:
                root.check(root.plain(root.find("managedProjectName_/fixture/repos/p79").text) === "&lt;A&amp;B&gt;",
                    "markup-like project names remain literal while highlighting")
                search.text = "SoloWorkspace"
                break
            case 15:
                root.check(!!root.find("projectSource_/fixture/single") && !!root.find("matchedWorkspace_/fixture/single/Solo.code-workspace"),
                    "workspace-only matches are also visible for single-folder sources")
                search.clear()
                break
            case 16:
                root.check(!root.find("managedProject_/fixture/single"),"unfiltered single-folder sources retain their compact presentation")
                if (!root.failed) console.log("PASS: project management highlights name/path/workspace matches and preserves editor/list scroll")
                stop(); Qt.quit()
            }
        }
    }
}
