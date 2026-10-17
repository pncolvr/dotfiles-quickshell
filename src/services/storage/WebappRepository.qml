pragma Singleton
import "../../config"
import "../webapps/WebappEntries.mjs" as Entries

ManagedCollectionRepository {
    tableName: 'webapps'
    entryLabel: 'collections.types.webapp'
    validateEntry: value => Entries.validate(value,Config.webappBrowsers)
}
