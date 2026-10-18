pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui" as UI
import "../../config"
import "../../services/webapps/WebappEntries.mjs" as Entries

Column {
    id: root
    property bool readOnly: false
    property string objectNamePrefix: 'webapp'
    property string browser: Config.defaultBrowserId
    property string browserProfile: ''
    property string windowMode: 'normal'
    readonly property var configuredBrowser: Config.browsers.find(browser=>browser.id===root.browser)
    spacing: Theme.controlSpacing
    Row {
        width: parent.width
        spacing: Theme.controlSpacing
    UI.ComboSelector { readOnly: root.readOnly;
        objectName:root.objectNamePrefix+'BrowserSelector'
        toggleObjectName:root.objectNamePrefix+'BrowserToggle'
        width: profilePicker.visible ? (parent.width - parent.spacing) / 2 : parent.width; compact:true; label: Translations.text("browser.selector.label", [selectedDescription])
        options: Config.browsers.map(browser => ({name:browser.id,description:browser.name}))
        selectedName: root.browser
        onSelected: name => {
            root.browser=name
            const browser=Config.browsers.find(browser=>browser.id===name)
            if (!browser?.profileArguments || !Entries.profileOptions(browser).some(profile=>profile.name===root.browserProfile)) root.browserProfile=''
            if (root.windowMode==='app' && !browser?.appArguments) root.windowMode='normal'
        }
    }
    UI.ComboSelector { readOnly: root.readOnly;
        id: profilePicker
        objectName:root.objectNamePrefix+'ProfileSelector'
        toggleObjectName:root.objectNamePrefix+'ProfileToggle'
        choicesObjectName:root.objectNamePrefix+'ProfileChoices'
        width: (parent.width - parent.spacing) / 2; compact:true; label: Translations.text("browser.profile.label", [selectedDescription])
        visible: !!root.configuredBrowser?.profileArguments
        options: Entries.profileOptions(root.configuredBrowser).map(option => Object.assign({},option,{description:option.name ? option.description : Translations.text("browser.profile.default")}))
        selectedName: root.browserProfile
        placeholder: Translations.text("browser.profile.unavailable")
        onSelected: name => root.browserProfile=name
    }
    }
    UI.ComboSelector { readOnly: root.readOnly;
        objectName:root.objectNamePrefix+'WindowSelector'
        width: parent.width; compact:true; label: Translations.text("browser.window.label", [selectedDescription])
        options: Entries.windowOptions(root.configuredBrowser).map(option => Object.assign({},option,{description:Translations.text(option.description)}))
        selectedName:root.windowMode; onSelected: name => root.windowMode=name
    }
}
