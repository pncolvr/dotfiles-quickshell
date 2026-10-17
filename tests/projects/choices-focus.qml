pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"
import "../launcher" as Fixtures

Scope {
    id: root
    readonly property string directory: Quickshell.env("PROJECT_CHOICES_TEST_DIR")
    property bool failed: false
    Fixtures.NativeFocusDriver {
        id: driver
        timeout: 1200
        onFailed: message => { root.failed = true; console.error("PROJECT CHOICES FAIL:", message); PickerService.close(); Qt.quit() }
        onCompleted: Qt.quit()
    }
    PickerWindow { id: popup }

    function check(condition, message) {
        if (!condition) throw new Error(message)
    }
    function project(name, withWorkspace = true) {
        const path = directory + "/projects/" + name
        return {path, name, workspaces: withWorkspace ? [
            {path:path + "/" + name + ".code-workspace", name, included:true},
            {path:path + "/Excluded.code-workspace", name:"Excluded", included:false}
        ] : []}
    }
    function openProjects() {
        driver.add("open projects", () => PickerService.projects())
        driver.waitFor("project picker opens with keyboard focus", () => PickerService.visible && popup.windowActive)
        driver.pause(60)
    }
    function activateChoices(name, mouse = false) {
        const project = root.project(name)
        driver.add(name + (mouse ? " click" : " Enter"), () => {
            const list = driver.find(popup.panel, "pickerList")
            check(!!list && PickerService.currentItem.result === project.path, "intended project is highlighted")
            if (mouse) driver.click(list.itemAtIndex(PickerService.currentIndex))
            else driver.key(Qt.Key_Return)
            check(PickerService.visible, "opening launch choices must not dismiss the picker")
        })
        driver.pause(100)
        driver.add("verify choices for " + name, () => {
            check(PickerService.visible && popup.visible && popup.windowActive, "choices keep the native window open and focused")
            check(ProjectService.projectPath === project.path
                && JSON.stringify(PickerService.items.map(row => row.title)) === JSON.stringify(["Open in Code", name]),
                "folder action precedes the included workspace, and exclusions stay excluded")
            check(PickerService.currentItem.result === project.path + "/" + name + ".code-workspace",
                "remembered workspace remains selected")
            check(driver.find(popup.panel, "pickerSearch").activeFocus, "choices search retains input focus")
        })
    }
    function back() {
        driver.add("back to projects", () => ProjectService.back())
        driver.pause(100)
    }
    Component.onCompleted: {
        driver.waitFor("database ready", () => DbService.ready)
        driver.add("seed projects", () => {
            const projects = [root.project("Alpha Project"), root.project("Beta Project"), root.project("Plain", false)]
            for (let index = 0; index < 76; index++) projects.push(root.project("Zulu " + String(index).padStart(3,"0"), false))
            root.check(ProjectRepository.apply([{path:root.directory + "/projects",kind:"root",category:"personal",error:"",projects}], true), "seed synthetic projects")
            for (const project of projects.slice(0, 2))
                PreferencesRepository.setValue("launcher.selection.projects.workspaces:" + project.path, project.path + "/" + project.name + ".code-workspace")
        })
        openProjects()
        driver.add("first project", () => check(PickerService.currentIndex === 0, "first project starts at index zero"))
        activateChoices("Alpha Project")
        back()
        driver.add("retained project list", () => check(PickerService.visible && ProjectService.projectPath === "" && PickerService.items.length === 79,
            "back to projects keeps the same native launcher open"))
        activateChoices("Alpha Project", true)
        back()
        driver.add("filter Beta", () => { driver.find(popup.panel, "pickerSearch").text = "Beta" })
        driver.pause(40)
        activateChoices("Beta Project")
        back()
        driver.add("second row", () => { PickerService.currentIndex = 1 })
        activateChoices("Beta Project", true)
        driver.add("close projects", () => PickerService.close())
        driver.waitFor("project window closes", () => !popup.visible)
        openProjects()
        driver.add("filter direct launch", () => { driver.find(popup.panel, "pickerSearch").text = "Plain" })
        driver.add("launch single option", () => {
            driver.key(Qt.Key_Return)
            check(!PickerService.visible && ProjectService.projectPath === "", "single-option project still launches directly")
        })
        driver.pause(100)
        driver.add("finished", () => console.log("PASS: native project choices survive first-row Enter/click, filtering, other rows and back; remembered workspace and direct launch preserved"))
        driver.running = true
    }
}
