pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"

Scope {
    id: root
    readonly property string directory: Quickshell.env("PROJECT_CHOICES_TEST_DIR")
    property bool failed: false
    Test.TestCase { id: events; when: false }
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
        console.log("PROJECT CHOICES STAGE", "open", ProjectService.projectPath)
        PickerService.projects()
        events.tryCompare(popup, "windowActive", true, 1200)
        events.wait(60)
        check(PickerService.visible && popup.windowActive, "project picker opens with keyboard focus")
    }
    function activateChoices(name, mouse = false) {
        console.log("PROJECT CHOICES STAGE",name,mouse ? "click" : "Enter")
        const project = ProjectRepository.projects.find(row => row.name === name)
        const list = events.findChild(popup.panel, "pickerList")
        check(!!list && PickerService.currentItem.result === project.path, "intended project is highlighted")
        if (mouse) events.mouseClick(list.itemAtIndex(PickerService.currentIndex), 20, 15, Qt.LeftButton, Qt.NoModifier, 0)
        else events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
        check(PickerService.visible, "opening launch choices must not dismiss the picker")
        events.wait(100)
        check(PickerService.visible && popup.visible && popup.windowActive, "choices keep the native window open and focused")
        check(ProjectService.projectPath === project.path
            && JSON.stringify(PickerService.items.map(row => row.title)) === JSON.stringify(["Open in Code", name]),
            "folder action precedes the included workspace, and exclusions stay excluded")
        check(PickerService.currentItem.result === project.path + "/" + name + ".code-workspace",
            "remembered workspace remains selected")
        check(events.findChild(popup.panel, "pickerSearch").activeFocus, "choices search retains input focus")
    }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            try {
                const projects = [root.project("Alpha Project"), root.project("Beta Project"), root.project("Plain", false)]
                for (let index = 0; index < 76; index++) projects.push(root.project("Zulu " + String(index).padStart(3,"0"), false))
                root.check(ProjectRepository.apply([{path:root.directory + "/projects",kind:"root",category:"personal",error:"",projects}], true), "seed synthetic projects")
                for (const project of projects.slice(0, 2))
                    PreferencesRepository.setValue("launcher.selection.projects.workspaces:" + project.path, project.path + "/" + project.name + ".code-workspace")

                root.openProjects()
                root.check(PickerService.currentIndex === 0, "first project starts at index zero")
                root.activateChoices("Alpha Project")
                ProjectService.back()
                events.wait(100)
                root.check(PickerService.visible && ProjectService.projectPath === "" && PickerService.items.length === 79,
                    "back to projects keeps the same native launcher open")
                root.activateChoices("Alpha Project", true)

                ProjectService.back()
                events.wait(100)
                const search = events.findChild(popup.panel, "pickerSearch")
                search.text = "Beta"
                events.wait(40)
                root.activateChoices("Beta Project")

                ProjectService.back()
                events.wait(100)
                PickerService.currentIndex = 1
                root.activateChoices("Beta Project", true)

                PickerService.close()
                events.tryCompare(popup, "visible", false, 800)
                root.openProjects()
                events.findChild(popup.panel, "pickerSearch").text = "Plain"
                events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
                root.check(!PickerService.visible && ProjectService.projectPath === "", "single-option project still launches directly")
                events.wait(100)
                console.log("PASS: native project choices survive first-row Enter/click, filtering, other rows and back; remembered workspace and direct launch preserved")
            } catch (error) {
                root.failed = true
                console.error("PROJECT CHOICES FAIL:", error)
            }
            Qt.quit()
        }
    }
}
