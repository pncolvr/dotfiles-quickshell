pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../"
import "../" as UI

Column {
    id: root
    property alias text: pathField.text
    property alias displayName: nameField.text
    property alias inputObjectName: pathField.inputObjectName
    property alias browseObjectName: pathField.browseObjectName
    property alias nameObjectName: nameField.objectName
    property alias categoryObjectName: categoryButton.objectName
    property alias kindObjectName: kindButton.objectName
    property alias placeholderText: pathField.placeholderText
    property alias dialogTitle: pathField.dialogTitle
    property alias folderPicker: pathField.folderPicker
    readonly property bool nativeDialogOpen: pathField.nativeDialogOpen
    property bool showName: false
    property bool showKind: false
    property string category: "personal"
    property string kind: "folder"
    signal accepted()
    signal categoryRequested(string category)
    signal kindRequested(string kind)
    spacing: Theme.controlSpacing
    function focusInput() { pathField.focusInput() }
    function clear() { pathField.clear(); nameField.clear() }

    UI.FolderPathField {
        id: pathField
        width: parent.width
        onAccepted: root.accepted()
    }
    RowLayout {
        width: parent.width
        spacing: Theme.controlSpacing
        UI.InputField {
            id: nameField
            visible: root.showName
            Layout.fillWidth: true
            placeholderText: "Name (optional)"
            pauseTooltipDismissal: false
            onAccepted: root.accepted()
        }
        UI.ActionButton {
            id: kindButton
            visible: root.showKind
            label: root.kind === "root" ? "Repositories root" : "Single folder"
            Layout.preferredWidth: Theme.projectOptionButtonWidth
            hint: "switch folder type"
            onClicked: root.kindRequested(root.kind === "root" ? "folder" : "root")
        }
        UI.FolderCategoryButton {
            id: categoryButton
            category: root.category
            Layout.preferredWidth: Theme.projectOptionButtonWidth
            onCategoryRequested: category => root.categoryRequested(category)
        }
        Item { visible: !root.showName; Layout.fillWidth: true }
    }
}
