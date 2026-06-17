# SQLite Storage Foundation

Step 41 introduces the first concrete local storage implementation while keeping
the deterministic bootstrap stores available for tests and contract scaffolding.

`SqliteStorageFoundation` is a Foundation/Storage implementation detail. It
persists the Phase C core storage domains through SQLite:

- schema metadata and migration version
- settings
- blob cache entries
- media cache buffered ranges
- media library catalog records
- playback history records
- provider bindings
- subtitle search and content cache records

Feature-specific stores outside this Step 41 core set are injected through a
fallback `StorageFoundation`. If no fallback is supplied, deterministic stores
are used for those out-of-scope domains. This is intentional: Step 41 proves the
core media-library persistence base without pretending every Phase 4-6 store now
has a concrete database schema.

## Usage

```dart
final SqliteStorageFoundation storage =
    SqliteStorageFoundation.open('celesteria.db');

await storage.settings.writeString(key: 'language', value: 'ja');
await storage.dispose();
```

For tests and smoke tools, use:

```dart
final SqliteStorageFoundation storage = SqliteStorageFoundation.inMemory();
```

## Boundaries

- UI, Domain, Playback, Provider, Streaming, and Network code must not import
  `package:sqlite3`, open database handles, or issue SQL.
- Consumers use existing `StorageFoundation` contracts.
- `DeterministicStorageFoundation` remains adapter-free and constructible
  without SQLite.
- Provider-facing cache policy still belongs to `ProviderGateway`; SQLite only
  stores records behind storage contracts.
