import QtQuick
import "../../src/services"
WorkerScope {
    id: root
    property bool failed: false
    function check(ok,message) { if (!ok) { failed = true; console.error("GROUPING FAIL:",message) } }
    function owner(tx,source,path,name,url) {
        tx.executeSql("INSERT INTO store.projects(source_path,path,name,remote_url) VALUES(?,?,?,?)",[source,path,name,url])
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            root.check(DbService.write(tx => {
                for (const source of ["/a-root","/b-root","/z-direct"]) tx.executeSql("INSERT INTO store.project_sources(path,kind,category) VALUES(?,?,?)",
                    [source,source === "/z-direct" ? "folder" : "root",source === "/a-root" ? "personal" : "work"])
                root.owner(tx,"/a-root","/projects/shared","Root choice","https://root.invalid/shared")
                root.owner(tx,"/b-root","/projects/shared","Second root","https://second.invalid/shared")
                root.owner(tx,"/z-direct","/projects/shared","Folder choice","https://folder.invalid/shared")
                root.owner(tx,"/a-root","/projects/tie-b","Same","https://root.invalid/b")
                root.owner(tx,"/a-root","/projects/tie-a","Same","https://root.invalid/a")
                root.owner(tx,"/a-root","__proto__","Prototype","https://root.invalid/prototype")
                root.owner(tx,"/a-root","constructor","Constructor","https://root.invalid/constructor")
                tx.executeSql("INSERT INTO store.project_workspaces VALUES('/projects/shared','/projects/shared/z','alpha',0)")
                tx.executeSql("INSERT INTO store.project_workspaces VALUES('/projects/shared','/projects/shared/a','Alpha',1)")
                tx.executeSql("INSERT INTO store.project_workspaces VALUES('/projects/shared','/projects/shared/zz','Zulu',1)")
            }),"seed synthetic overlapping sources")
            root.check(ProjectRepository.reload(),"reload succeeds")
            let shared = ProjectRepository.projects.find(project => project.path === "/projects/shared")
            root.check(ProjectRepository.projects.length === 5,"overlapping sources yield one project per path")
            root.check(shared.source === "/z-direct" && shared.name === "Folder choice" && shared.category === "work"
                && shared.url === "https://folder.invalid/shared","single-folder metadata takes priority over roots")
            root.check(JSON.stringify(shared.sourcePaths) === JSON.stringify(["/z-direct","/a-root","/b-root"]),"all owners retain SQL priority order")
            root.check(shared.workspaces.length === 3 && shared.workspaces[0].path.endsWith("/a")
                && shared.workspaces[1].path.endsWith("/z") && shared.workspaces[2].name === "Zulu"
                && shared.workspaces[0].included && !shared.workspaces[1].included,"workspace sort/tie order and inclusion remain intact")
            root.check(ProjectRepository.projects.filter(project => project.name === "Same").map(project => project.path).join(",")
                === "/projects/tie-a,/projects/tie-b","project sort retains path tie-break")
            root.check(ProjectRepository.projects.some(project => project.path === "__proto__")
                && ProjectRepository.projects.some(project => project.path === "constructor"),"path keys cannot collide with object prototypes")
            root.check(ProjectRepository.projects.find(project => project.path === "constructor").workspaces.length === 0,"project without workspaces remains valid")
            root.check(ProjectRepository.removeSource("/z-direct"),"remove primary source")
            shared = ProjectRepository.projects.find(project => project.path === "/projects/shared")
            root.check(shared.source === "/a-root" && shared.name === "Root choice" && shared.category === "personal"
                && shared.url === "https://root.invalid/shared" && shared.workspaces[0].included
                && shared.sourcePaths.join(",") === "/a-root,/b-root","removal falls back to the next owner and preserves choices")
            const projects = ProjectRepository.projects
            const sources = ProjectRepository.sources
            root.check(DbService.write(tx => tx.executeSql("ALTER TABLE store.project_workspaces RENAME TO unavailable_workspaces")),"simulate unavailable workspace data")
            root.check(!ProjectRepository.reload() && ProjectRepository.projects === projects && ProjectRepository.sources === sources,"failed read preserves the complete successful snapshot")
            root.check(DbService.write(tx => tx.executeSql("ALTER TABLE store.unavailable_workspaces RENAME TO project_workspaces"))
                && ProjectRepository.reload() && !ProjectRepository.error,"reload recovers without dropping records")
            if (!root.failed) console.log("PASS: project grouping preserves owners, priority, sorting, choices, fallback and failed-read snapshots")
            Qt.quit()
        }
    }
}
