pragma Singleton
import "../remotes/RemoteEntries.mjs" as Entries

ManagedCollectionRepository {
    tableName: 'remotes'
    entryLabel: 'remote'
    validateEntry: Entries.validate
}
