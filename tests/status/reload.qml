pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/modules/status"
import "../../src/ui" as UI

Scope {
    id: root
    readonly property string generation: Date.now() + '-' + Math.random()
    property bool loaded: false
    function find(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        for (const child of item.children ?? []) {
            const result = find(child, name);
            if (result)
                return result;
        }
        return null;
    }
    QtObject {
        id: backend
        property var rules: ({
                workDirectories: ['/synthetic/first'],
                processes: ['fixture-process']
            })
        property string rulesError: ''
        function saveRules(value) {
            rules = value;
            return true;
        }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 700
        implicitHeight: 600
        StatusRulesEditor {
            id: editor
            width: 650
            statusService: backend
        }
        // Prime the existing UI module metadata before adding a shared component.
        UI.ColumnText {
            visible: false
            text: 'fixture'
        }
    }
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
        }
        function onReloadFailed() {
            Quickshell.inhibitReloadPopup();
        }
    }
    Component.onCompleted: {
        Qt.callLater(() => {
            editor.load();
            root.loaded = true;
        });
    }
    IpcHandler {
        target: 'statusReloadTest'
        function state(): string {
            const field = root.find(editor, 'statusWorkFoldersList');
            return JSON.stringify({
                loaded: root.loaded,
                generation: root.generation,
                multiple: !!field,
                text: field?.text ?? ''
            });
        }
        function exercise(): string {
            const field = root.find(editor, 'statusWorkFoldersList');
            if (!field)
                return JSON.stringify({
                    ok: false
                });
            field.folderPicker.folderSelected('/synthetic/second');
            field.folderPicker.folderSelected('/synthetic/second');
            root.find(editor, 'statusRulesActions').submitted();
            return JSON.stringify({
                folders: backend.rules.workDirectories,
                text: field.text,
                dirty: editor.dirty
            });
        }
        function reload(): void {
            Qt.callLater(() => Quickshell.reload(true));
        }
        function quit(): void {
            Qt.quit();
        }
    }
}
