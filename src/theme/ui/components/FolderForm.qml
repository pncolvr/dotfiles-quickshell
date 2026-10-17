pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import QtQuick.Layouts
import "../../"
import "../" as UI

Column {
    id: root
    property bool readOnly: false
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
    property bool showCategory: true
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
        readOnly: root.readOnly
        width: parent.width
        onAccepted: root.accepted()
    }
    RowLayout {
        width: parent.width
        spacing: Theme.controlSpacing
        UI.InputField {
            id: nameField
            readOnly: root.readOnly
            visible: root.showName
            Layout.fillWidth: true
            placeholderText: Translations.text("timers.fields.nameOptional")
            retainPanelWhileEditing: false
            onAccepted: root.accepted()
        }
        UI.ComboSelector {
            id: kindButton
            visible: root.showKind
            readOnly: root.readOnly
            compact: true
            selectedName: root.kind
            options: [
                {name: "folder", description: Translations.text("projects.source.singleFolder")},
                {name: "root", description: Translations.text("projects.source.repositoryRoot")}
            ]
            Layout.fillWidth: true
            Layout.preferredWidth: Theme.projectOptionButtonWidth
            onSelected: name => root.kindRequested(name)
        }
        UI.FolderCategorySelector {
            id: categoryButton
            visible: root.showCategory
            category: root.category
            readOnly: root.readOnly
            Layout.fillWidth: true
            Layout.preferredWidth: Theme.projectOptionButtonWidth
            onCategoryRequested: category => root.categoryRequested(category)
        }
    }
}
