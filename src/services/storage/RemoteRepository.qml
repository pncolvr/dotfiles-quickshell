pragma Singleton
import "../remotes/RemoteEntries.mjs" as Entries

ManagedCollectionRepository {
    tableName: 'remotes'
    entryLabel: 'collections.types.remote'
    validateEntry: Entries.validate
}
