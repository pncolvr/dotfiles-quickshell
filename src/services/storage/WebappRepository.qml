pragma Singleton
import "../../config"
import "../webapps/WebappEntries.mjs" as Entries

ManagedCollectionRepository {
    tableName: 'webapps'
    entryLabel: 'webapp'
    validateEntry: value => Entries.validate(value,Config.webappBrowsers)
}
