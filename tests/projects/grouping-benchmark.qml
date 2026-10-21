import QtQuick
import Quickshell
import "../../src/services"
WorkerScope {
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            const count = Number(Quickshell.env("PROJECT_GROUPING_BENCH_COUNT") || 2000)
            if (!ProjectRepository.projects.length) {
                if (!DbService.write(tx => {
                    for (let source = 0; source < 3; source++) tx.executeSql("INSERT INTO store.project_sources(path,kind,category) VALUES(?,?,?)",
                        ["/benchmark/source-" + source,source === 0 ? "folder" : "root",source === 0 ? "work" : "personal"])
                    for (let i = 0; i < count; i++) {
                        const path = "/benchmark/projects/project-" + i
                        for (let source = 0; source < 3; source++) tx.executeSql("INSERT INTO store.projects(source_path,path,name,remote_url) VALUES(?,?,?,?)",
                            ["/benchmark/source-" + source,path,"Project " + i,"https://example.invalid/project-" + i])
                        for (let workspace = 0; workspace < 3; workspace++) tx.executeSql("INSERT INTO store.project_workspaces(project_path,path,name,included) VALUES(?,?,?,?)",
                            [path,path + "/Workspace-" + workspace + ".code-workspace","Workspace " + workspace,workspace !== 2 ? 1 : 0])
                    }
                })) { console.error("GROUPING BENCH FAIL: seed"); Qt.quit(); return }
            }
            ProjectRepository.reload()
            const reloadMs = []
            for (let iteration = 0; iteration < 3; iteration++) {
                const start = Date.now()
                if (!ProjectRepository.reload()) { console.error("GROUPING BENCH FAIL: reload"); Qt.quit(); return }
                reloadMs.push(Date.now() - start)
            }
            if (ProjectRepository.projects.length !== count || ProjectRepository.projects.some(project => project.sourcePaths.length !== 3
                || project.source !== "/benchmark/source-0" || project.workspaces.length !== 3 || project.workspaces[2].included)) {
                console.error("GROUPING BENCH FAIL: snapshot"); Qt.quit(); return
            }
            const rows = ProjectRepository.projects.map(project => ({id:project.path,title:project.name,search:project.name + " " + project.path}))
            const queries = ["pro", "prj", "project 199", "doesnotexist"]
            const searchMs = {}
            for (const query of queries) {
                PickerService.filter(rows,query)
                const times = []
                for (let iteration = 0; iteration < 5; iteration++) {
                    const start = Date.now(); PickerService.filter(rows,query); times.push(Date.now() - start)
                }
                searchMs[query] = times
            }
            console.log("GROUPING BENCH",JSON.stringify({phase:Quickshell.env("PROJECT_GROUPING_BENCH_PHASE"),projects:count,owners:count * 3,
                workspaces:count * 3,reloadMs,searchMs}))
            console.log("PASS: project reload and existing in-memory search benchmark")
            Qt.quit()
        }
    }
}
