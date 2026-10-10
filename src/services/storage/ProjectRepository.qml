pragma Singleton
import QtQml
import Quickshell
import "../"

Singleton {
    id: root
    property var sources: []
    property var projects: []
    property string error: ""

    function reload() {
        const sourceRows = DbService.read("SELECT * FROM project_sources ORDER BY path")
        const projectRows = DbService.read("SELECT p.*, s.category, s.kind FROM projects p JOIN project_sources s ON p.source_path = s.path ORDER BY CASE s.kind WHEN 'folder' THEN 0 ELSE 1 END, s.path, p.path")
        const workspaces = DbService.read("SELECT * FROM project_workspaces ORDER BY name COLLATE NOCASE,path")
        if (sourceRows === null || projectRows === null || workspaces === null) { error = DbService.error; return false }
        sources = sourceRows
        const unique = []
        for (const row of projectRows) {
            if (unique.some(project => project.path === row.path)) continue
            unique.push({path:row.path, name:row.name, category:row.category, url:row.remote_url,
                source:row.source_path, sourcePaths:projectRows.filter(project => project.path === row.path).map(project => project.source_path),
                workspaces:workspaces.filter(workspace => workspace.project_path === row.path)
                    .map(workspace => ({path:workspace.path, name:workspace.name, included:workspace.included === 1}))})
        }
        projects = unique.sort((a,b) => a.name.localeCompare(b.name) || a.path.localeCompare(b.path))
        error = ""
        return true
    }
    function prune(tx) {
        tx.executeSql("DELETE FROM project_workspaces WHERE project_path NOT IN (SELECT path FROM projects)")
    }
    function apply(results, adding = false) {
        if (!DbService.write(tx => {
            for (const source of results) {
                if (adding && source.error) throw new Error(source.error)
                if (adding) tx.executeSql("INSERT INTO project_sources (path,kind,category) VALUES (?,?,?)", [source.path,source.kind,source.category])
                tx.executeSql("UPDATE project_sources SET error = COALESCE(?, ''), refreshed_at = ? WHERE path = ?", [source.error || "",Date.now(),source.path])
                if (source.error) continue
                tx.executeSql("DELETE FROM projects WHERE source_path = ?", [source.path])
                for (const project of source.projects) {
                    tx.executeSql("INSERT INTO projects (source_path,path,name,remote_url) VALUES (?,?,?,COALESCE(?, ''))", [source.path,project.path,project.name,project.url || ""])
                    const old = tx.executeSql("SELECT path FROM project_workspaces WHERE project_path = ?", [project.path]).rows
                    const previous = []
                    for (let i=0;i<old.length;i++) previous.push(old.item(i).path)
                    for (const workspace of project.workspaces) {
                        tx.executeSql("INSERT OR IGNORE INTO project_workspaces (project_path,path,name,included) VALUES (?,?,?,?)", [project.path,workspace.path,workspace.name,adding && workspace.included ? 1 : 0])
                        tx.executeSql("UPDATE project_workspaces SET name = ? WHERE project_path = ? AND path = ?", [workspace.name,project.path,workspace.path])
                        if (workspace.included !== undefined) tx.executeSql("UPDATE project_workspaces SET included = ? WHERE project_path = ? AND path = ?", [workspace.included ? 1 : 0, project.path, workspace.path])
                    }
                    for (const path of previous) {
                        if (!project.workspaces.some(workspace => workspace.path === path)) tx.executeSql("DELETE FROM project_workspaces WHERE project_path = ? AND path = ?", [project.path,path])
                    }
                }
                root.prune(tx)
            }
        })) { error = DbService.error; return false }
        return reload()
    }
    function saveEdit(projects, sourcePath, category) {
        if (sourcePath && !['work','personal'].includes(category)) return false
        if (!DbService.write(tx => {
            if (sourcePath) tx.executeSql("UPDATE project_sources SET category = ? WHERE path = ?", [category,sourcePath])
            for (const project of projects) {
                for (const workspace of project.workspaces) tx.executeSql("UPDATE project_workspaces SET included = ? WHERE project_path = ? AND path = ?", [workspace.included ? 1 : 0,project.path,workspace.path])
            }
        })) { error = DbService.error; return false }
        return reload()
    }
    function removeSource(path) {
        if (!DbService.write(tx => {
            tx.executeSql("DELETE FROM projects WHERE source_path = ?", [path])
            tx.executeSql("DELETE FROM project_sources WHERE path = ?", [path])
            root.prune(tx)
        })) { error = DbService.error; return false }
        return reload()
    }
    Component.onCompleted: reload()
}
