## Why

Step 1-40 completed contract scaffolding, runtime bootstrap, concrete playback
binding, and Phase B provider/playback smoke gates. Phase C now needs a real
local persistence foundation before media library and history runtimes can move
from deterministic in-memory acceptance stores to restart-safe storage.

The current deterministic storage foundation remains required for tests and
contract scaffolding, but it does not prove that metadata, settings, media
library records, playback history, provider bindings, subtitle cache records,
blob cache entries, or buffered ranges survive process restart.

## What Changes

- Add a concrete SQLite-backed storage foundation for core local storage
  domains:
  - schema metadata/migration version;
  - settings;
  - blob cache;
  - media cache buffered ranges;
  - media library catalog records;
  - playback history records;
  - provider bindings;
  - subtitle search/content cache records.
- Keep `DeterministicStorageFoundation` unchanged and constructible without
  SQLite.
- Allow feature-specific stores outside the Step 41 core set to be injected, or
  to fall back to deterministic stores until their concrete persistence changes.
- Add focused restart/persistence tests and a non-UI smoke checker.
- Add boundary checks preventing SQLite implementation details from leaking to
  UI, Provider, Playback, Streaming, Network, or Domain consumers.

## Non-Goals

- No UI, app shell, `lib/main.dart`, `windows/**`, file picker, or widget work.
- No concrete SQLite implementation for every feature-specific Phase 4-6 store
  in this change.
- No provider-owned cache tables or direct provider database access.
- No cloud sync, remote storage, telemetry persistence, or platform filesystem
  plugin.

## Impact

- Adds `sqlite3` as the first concrete local metadata dependency.
- Introduces a storage implementation detail under Foundation/Storage while
  preserving the existing `StorageFoundation` contract.
- Provides a real persistence baseline for Step 42 media library runtime work.
