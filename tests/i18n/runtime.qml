pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/config" as Settings
import "../../src/i18n"
import "../../src/modules/clock"
import "../../src/modules/system/stats"
import "../../src/services"
import "../../src/theme/ui" as UI

Scope {
    id: root
    property var settings: Settings.Config
    property bool failed: false
    Test.TestCase { id: events; when: false }
    function check(value, message) { if (!value) { failed=true; console.error('I18N FAIL:',message) } }
    QtObject {
        id: memory
        property real memoryUsed: 6000
        property real memoryTotal: 64000
        property real memoryFree: 30000
        property real memoryAvailable: 58000
        property real memoryCache: 20000
        property real swapUsed: 0
        property real swapTotal: 16000
    }
    function hasText(item, wanted) {
        if (item.text === wanted) return true;
        return Array.from(item.children ?? []).some(child => hasText(child,wanted));
    }
    FloatingWindow {
        id: window
        color: Settings.Theme.background
        visible: true; implicitWidth: 640; implicitHeight: 700
        Column {
            width: 600
            UI.TabBar { id: tabs; width: parent.width; labels: [Translations.text('stats.tabs.overview'),Translations.text('stats.tabs.memory')] }
            UI.InputField { id: input; width: parent.width; text: 'user content'; placeholderText: Translations.text('clipboard.search.placeholder') }
            UI.ComboSelector {
                id: selector; width: parent.width; selectedName: "user-profile"
                options: [{name:"user-profile",description:"Perfil %2 pessoal"}]
                label: Translations.text("browser.profile.label", [selectedDescription])
            }
            MemoryTooltip { id: memoryPanel; width: 480; statsService: memory }
            MonthTooltip { id: calendar }
        }
    }
    Timer {
        running: true; interval: 100
        onTriggered: {
            root.settings.language='en'
            events.wait(20)
            root.check(Translations.language==='en','explicit English')
            root.check(Translations.text('common.actions.save')==='Save','English catalog loaded')
            root.check(Translations.calendarMonthNames[2]==='march','English calendar')
            root.settings.language='pt'
            events.wait(20)
            root.check(Translations.text('common.actions.save')==='Guardar','Portuguese catalog loaded')
            root.check(Translations.calendarMonthNames[2]==='março','Portuguese calendar')
            root.check(Translations.calendarDayNames.length===7,'seven weekday headings')
            root.check(tabs.labels[0]==='Resumo','translated tab binding updates')
            root.check(input.text==='user content','user content preserved')
            root.check(selector.selectedName==='user-profile' && selector.label==='Perfil: Perfil %2 pessoal','selected ID and literal placeholder-like user data preserved')
            root.check(PowerService.actions[0].result==='Reboot' && PowerService.actions[0].title==='Reiniciar','translated action label preserves dispatch code')
            root.check(root.hasText(memoryPanel,'Livre') && root.hasText(memoryPanel,'Disponível') && root.hasText(memoryPanel,'Em cache'),'memory labels translate while model keys stay stable')
            root.check(Translations.message({key:'files.errors.unsetVariable',args:['EXAMPLE']})==='A variável de ambiente não está definida: EXAMPLE.','structured diagnostics translate without exposing raw IDs')
            const error = Object.assign(new Error("projects.errors.unknownPlaceholder"),{args:["{custom}"]});
            root.check(Translations.message(error)==='Parâmetro desconhecido no lançador de projetos: {custom}','parameterized model errors translate through the shared boundary')
            root.check(Translations.message('external tool output')==='external tool output','external diagnostics preserved')
            root.check(Translations.text('tabs.actions.remove',['%2 ficheiros'])==='Remover separador %2 ficheiros','complete parameterized message uses one interpolation pass')
            root.check(input.placeholderText==='Pesquisar na área de transferência','placeholder updates')
            root.check(calendar.isTodayWeekday(new Date().getDay()===0?6:new Date().getDay()-1),'weekday uses index')
            input.forceActiveFocus(); events.keyClick(Qt.Key_A,Qt.NoModifier,0)
            root.check(input.activeFocus,'focus survives translation update')
            const preview = Quickshell.env("I18N_PREVIEW");
            if (preview) events.grabImage(window.contentItem).save(preview);
            root.settings.language='unknown'
            events.wait(20)
            root.check(Translations.language==='en','unsupported language falls back')
            root.check(Translations.text('common.actions.save')==='Save','fallback binding')
            if (!root.failed) console.log('PASS: QML catalogs, live bindings, calendar indexes, user data and focus')
            Qt.quit()
        }
    }
}
