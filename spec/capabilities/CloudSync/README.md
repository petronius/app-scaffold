# CloudSync

The local store and the sync that keeps it consistent across the user's devices through the CloudKit **private database**: one record per fact, `CKSyncEngine` doing the scheduling. No server of our own; nothing leaves the user's iCloud account, and the payloads are end-to-end encrypted.

## Purpose

Each device is complete on its own: it opens, reads and writes its store with no connection and with iCloud off. Two devices signed in to the same Apple account should show the same data, and an edit made on one should never be overwritten by an older copy from the other. Data a device can derive for itself from synced facts is never synced: each device derives it, and the derivations agree because the facts do.

## Source files

| File | Key logic |
|---|---|
| `Core/Sources/AppCore/Sync/SyncRecordType.swift` | The record types, their record-name prefixes, `parse(recordName:)`. |
| `Core/Sources/AppCore/Sync/SyncResolution.swift` | `SyncStamp`, `SyncEnvelope` (a record without CloudKit), `LocalSyncStamp`, `SyncResolution.decide` (the rules, pure), `SyncCoding` (the one JSON form). |
| `Core/Sources/AppData/AppDatabase.swift` | The store: `DatabasePool` in the App Group container, the migrations, suspension, `stamp(_:after:)`. |
| `Core/Sources/AppData/AppDatabase+Items.swift` | The example table's reads, writes and tombstoning delete, and `itemsStream()`. |
| `Core/Sources/AppData/AppDatabase+Sync.swift` | `pendingRecordNames`, `outgoing`, `localStamp`, `apply`, `markSynced`, `saveSystemFields`, `removeLocal`, `resetSyncMetadata`; the `syncMeta` and `syncState` tables. |
| `Core/Sources/AppSync/RecordMapping.swift` | Envelopes to `CKRecord` and back; archived system fields. |
| `Core/Sources/AppSync/CloudSync.swift` | The actor: the engine, its events, conflict handling, account and zone changes, `Status` and `Report`. |
| `Shared/Sources/StoreModel.swift` | What the views see: `items`, the edit methods (each one store write, then a push and a widget reload), the toggle, `syncNow`. |
| `Shared/Sources/AppIdentifiers.swift` | The App Group, the container, the zone name, the toggle's key. |
| `project.yml` | The iCloud, App Group and push entitlements of each target; `UIBackgroundModes: [remote-notification]`. |
| `Scripts/cloudkit-schema.ckdb`, `Scripts/cloudkit-schema.sh` | The record types as a checked-in schema and the import into Development. |

## Data model

One custom zone (`AppIdentifiers.syncZone`) in the private database. Every record type carries the same fields:

| Field | Type | Meaning |
|---|---|---|
| `payload` | Bytes, encrypted | The model as `SyncCoding` JSON (sorted keys, dates as seconds); absent on a tombstone |
| `editedAt` | Int64 | The store's `updatedAt` for the row, in milliseconds: when the user made the edit. Never invented by the sync |
| `editedBy` | String | The writing install's id (`syncState.deviceID`, minted on first use): the tie-break |
| `schemaVersion` | Int64 | The payload format (`SyncResolution.schemaVersion`); a record stamped higher is left alone |
| `deleted` | Int64 | 1 for a tombstone |

| Record type | Record name | Local table | Resolve | Notes |
|---|---|---|---|---|
| `Item` | `item-{uuid}` | `item` | newer wins | The example. Tombstone on delete |

### Edit stamps and tombstones

Every synced table carries `updatedAt`, written by the store in the same statement as the edit, and `deletedAt`. Reads skip rows with `deletedAt` set; a delete sets both. A stamp is never earlier than the row's previous one, so a device clock that moved back cannot make a newer edit lose. Housekeeping that is not the user's edit never touches `updatedAt`, so it never pushes, and every device does its own.

Tombstones are kept indefinitely, locally and in iCloud. Removing a deleted record would let a device that was offline, or a fresh install seeding from an old backup, bring the row back. A few hundred payload-free records a year is the whole cost.

### Local book-keeping

- `syncMeta(recordName, recordType, pushedAt, systemFields)`: per record, the stamp this device last pushed or applied, and CloudKit's archived system fields as last seen, so a save presents the right change tag. A row is pending when its `updatedAt` is past `pushedAt`. An applied record is marked pushed too, so a mirrored row never bounces back.
- `syncState` (one row): this install's `deviceID`, and `CKSyncEngine`'s own archived state (change tokens, pending changes).

## The engine (`CloudSync`, an actor)

`start()` restores the engine from its saved state, queues every pending row and reports the account status. A first start also queues the zone. Local edits call `push(_:)` with the record names the store returned; the engine sends a moment later on its own. `syncNow()` fetches and sends at once: pull to refresh, and every return to the foreground. Silent pushes from the engine's subscription wake a device when another one saves.

Fetch: each fetched record becomes a `SyncEnvelope` and is judged by `SyncResolution.decide` against the local row's stamp:

| Decision | Rule | Effect |
|---|---|---|
| `alreadySame` | same tombstone state and same payload | mark synced at the later stamp, keep the system fields |
| `applyRemote` | no local row, or the remote's `editedAt` is newer, or equal stamps and the remote's `editedBy` is larger | `apply`: written stamped with the remote's time, marked synced |
| `keepLocal` | the local stamp is newer, or equal and this device's id is larger | remember the server's system fields, queue the row; the next send overwrites the server copy |
| `unsupportedSchema` | `schemaVersion` newer than this build's | left alone, counted in the report |

A record deleted on the server outright (the app itself only writes tombstones) removes the local row.

Send: the engine asks `nextRecordZoneChangeBatch` for records; each is built on its archived system fields, so a lost race comes back as `serverRecordChanged` rather than an overwrite. That conflict is judged like a fetched record: applied if the server's copy wins, or the row is queued again over the server's change tag. `zoneNotFound` re-creates the zone and re-queues; `unknownItem` drops the stale change tag and re-queues. Transient errors are the engine's to retry. Any other refusal (a type missing from the production schema, a payload over the size limit) leaves the row pending and shows on the status row with CloudKit's message, the error code and the record name.

### Account and zone changes

| Event | Effect |
|---|---|
| Sign in | Forget the server book-keeping, restart the engine: every local row goes up, and conflicts with what is there resolve as usual |
| Switch accounts | The same. Local data stays: it is the user's, on their device |
| Sign out | Forget the server book-keeping; the status reads No iCloud account |
| Zone deleted or purged (the user deleted the app's iCloud data) | Forget the book-keeping, stop, turn the toggle off. Re-uploading would undo the user's choice; turning sync on again uploads this device's copy |
| Encrypted data reset (the user reset their iCloud Keychain) | Forget the book-keeping and upload again, as Apple advises |

The toggle wipes nothing. Off stops the engine and keeps its state; on starts it from that state.

## Phone, watch and widgets

The phone and the watch each run a `StoreModel` with its own store and its own `CloudSync`, against the same container: peers, so the watch works with the phone out of reach. Each device's widgets read that device's store read-only from the App Group container (`ItemsProvider`). `StoreModel` reloads the widget timelines after every local write and every applied fetch.

The app posts `AppDatabase.suspend()` when it leaves the foreground, so it holds no lock on the shared file while suspended (the system kills an app that does, with code 0xdead10cc), and `resume()` when it returns.

## Schema deployment

CloudKit creates record types on its own only in the Development environment. `Scripts/cloudkit-schema.ckdb` is the source of truth: `Scripts/cloudkit-schema.sh` imports it into Development, and the CloudKit Console promotes Development to Production before the TestFlight build that needs it. Promotion is additive only: a deployed type or field can never be removed or retyped.

## Syncing a new type

1. The model in `AppCore`, `Codable` and `Sendable`, with no storage fields. New optional fields decode leniently, so older builds ignore them.
2. A case in `SyncRecordType` with its record type name and prefix. Permanent once shipped.
3. A migration creating the table with `id`, `payload`, `updatedAt`, `deletedAt` and the columns its queries need; `SyncRecordType.table` names it.
4. The type's reads, writes and tombstoning delete in a new `AppDatabase+<Type>.swift`, after `AppDatabase+Items.swift`; each write returns the record name.
5. The type's case in `AppDatabase.apply`: decode the payload, write the row and its columns.
6. The record type in `Scripts/cloudkit-schema.ckdb`, imported into Development and deployed to Production before release.
7. The edit methods in `StoreModel`, through `write`, so each edit pushes and reloads the widgets.
8. Tests: the store's reads, writes, tombstones and `apply` in `AppDataTests`; any new resolution rule in `SyncResolutionTests`.
9. This page's record-type table, and the Library article that tells the user what syncs.

A type whose rows must merge rather than replace (a set that both devices add to) keeps newer-wins per record by naming records by content, so two devices name the same fact alike, or by giving each element its own record.
