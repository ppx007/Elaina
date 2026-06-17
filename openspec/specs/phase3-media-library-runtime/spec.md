# phase3-media-library-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase3-media-library-runtime. Update Purpose after archive.
## Requirements
### Requirement: Media library runtime SHALL compose existing Domain media contracts
The system SHALL provide a deterministic media-library runtime or bootstrap that wires `MediaLibraryScanner`, `MediaLibraryCatalogRepository`, `MediaBatchImportContract`, `PlaybackHistoryStore`, `ProviderBindingStore`, `PlaybackSourceHandoffContract`, and `CacheInvalidationBus` behind a Domain-facing runtime surface.

#### Scenario: Runtime is bootstrapped
- **WHEN** the media-library runtime is created with deterministic scanner, catalog, import, history, binding, handoff, and invalidation dependencies
- **THEN** callers can use one runtime surface for scan, import, catalog, continue-watching, binding, and local playback actions without importing storage implementations, provider runtimes, UI widgets, network clients, streaming engines, diagnostics, MPV, VLC, or native-player bindings

### Requirement: Media library runtime SHALL expose deterministic snapshots and failures
The media-library runtime SHALL expose lifecycle-safe snapshots, result values, and typed failures for idle, scanning, importing, ready, failed, and disposed states.

#### Scenario: Runtime is disposed
- **WHEN** a caller invokes a media-library action after disposal
- **THEN** the runtime returns or publishes a deterministic disposed/unavailable outcome instead of throwing provider, storage, UI, network, platform, playback, or native-player exceptions

### Requirement: Media library runtime SHALL support scan and import actions
The media-library runtime SHALL normalize scan scopes, execute deterministic scans, expose scan events, import accepted candidates into the catalog, report duplicate and failed import outcomes, and publish cache invalidation for imported catalog items.

#### Scenario: Scan candidates are imported
- **WHEN** a supported scan scope discovers local media candidates and the runtime imports them
- **THEN** catalog items are created or skipped deterministically, failures remain typed, and imported item changes are published without requiring filesystem traversal, database migration, provider metadata, RSS, subtitle provider, seasonal indexing, BT, online-rule, network, UI, or native-player behavior

### Requirement: Media library runtime SHALL project catalog, continue-watching, and binding state
The media-library runtime SHALL expose catalog listing/detail state together with latest continue-watching entries and strongest provider bindings while preserving user-confirmed binding precedence.

#### Scenario: Catalog state is loaded
- **WHEN** catalog items have playback history and provider bindings
- **THEN** the runtime snapshot includes media items, continue-watching state, and binding state derived from existing Domain media contracts without creating media-library-local duplicate state models

### Requirement: Media library runtime SHALL route local playback through handoff contracts
The media-library runtime SHALL route play actions for catalog items or scan candidates through `PlaybackSourceHandoffContract` and return explicit success, unavailable, or unsupported outcomes.

#### Scenario: Catalog item is played
- **WHEN** a catalog item with a file-backed `LocalMediaIdentity` is selected for playback
- **THEN** the runtime prepares playback through `PlaybackSourceHandoffContract` rather than constructing playback sources in UI, scanner, storage, provider, network, streaming, MPV, VLC, or native-player code

### Requirement: Media library runtime MUST preserve Step 14 boundaries
The media-library runtime MUST NOT implement subtitle provider, RSS engine, seasonal indexer, yuc.wiki feed consumption, BT streaming, online-rule parsing, concrete Flutter UI, ProviderGateway internals, storage migrations, platform filesystem traversal, diagnostics, MPV/VLC, or native-player bindings.

#### Scenario: Runtime boundaries are checked
- **WHEN** validation scans Step 14 runtime, tests, and tool files
- **THEN** forbidden later-phase dependencies and concrete implementation shortcuts are rejected while Domain media, playback handoff, and cache invalidation contracts remain allowed

### Requirement: Media library runtime SHALL provide concrete local-file scanning
The media-library runtime implementation SHALL provide a concrete local-file
scanner that traverses file-system directories, filters by normalized media
scan scope, emits existing scan events, and returns existing
`MediaScanCandidate` values without requiring UI file picker code.

#### Scenario: Local directory is scanned
- **WHEN** a file-backed scan scope points at a directory containing supported
  media files
- **THEN** the scanner returns accepted candidates with file URIs, basenames,
  sizes, optional duration metadata, and discovered timestamps using existing
  Domain media contracts

### Requirement: Media library runtime SHALL compose storage-backed repositories
The media-library runtime SHALL provide a composition path that adapts
`StorageFoundation` media catalog, playback history, and provider binding
contracts into the existing Domain media runtime repositories.

#### Scenario: Runtime is created with concrete storage
- **WHEN** an app composition root provides a `StorageFoundation`,
  `MediaLibraryScanner`, `PlaybackSourceHandoffContract`, and
  `CacheInvalidationBus`
- **THEN** the media-library runtime can scan, import, refresh catalog state,
  record playback history, save provider bindings, and route local playback
  without importing SQLite packages, SQL statements, UI widgets, provider
  clients, streaming engines, network clients, or native player bindings

### Requirement: Storage-backed media library runtime SHALL replay state after restart
The storage-backed media-library runtime SHALL rebuild catalog, continue
watching, and binding projections from storage after a runtime restart.

#### Scenario: Runtime restarts after import and history updates
- **WHEN** media items, playback history, and provider bindings were persisted
  through the storage-backed runtime
- **THEN** a later runtime composed with the same storage database can refresh
  and expose the imported catalog items, continue-watching entries, strongest
  provider bindings, and playback handoff support

### Requirement: Concrete media library implementation SHALL preserve UI ownership boundaries
Concrete media-library runtime implementation work SHALL provide core runtime
composition, tests, checkers, and integration notes without adding or
modifying Flutter app shell, media-library pages, routes, file picker UX,
thumbnail widgets, playback pages, Windows runner files, or UI state
composition.

#### Scenario: Step 42 is implemented
- **WHEN** Step 42 adds concrete scanner and storage-backed runtime composition
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain media contracts and composition
  notes rather than concrete SQLite, SQL, scanner internals, or storage row
  models

### Requirement: Media library runtime SHALL integrate playback history from playback snapshots
The media-library runtime implementation SHALL provide a non-UI integration
surface that records playback progress from `PlaybackStateSnapshot` values into
the existing `PlaybackHistoryStore`.

#### Scenario: Playback snapshot records progress
- **WHEN** playback state contains a catalog-backed `sourceUri`, a timeline
  position, and a duration
- **THEN** the integration resolves the catalog item, writes a
  `PlaybackHistoryEntry`, publishes `HistoryRecorded`, and returns a typed
  success result without requiring UI widgets, concrete player bindings,
  SQLite packages, SQL statements, provider clients, RSS, BT, network policy,
  diagnostics, or native player callbacks

### Requirement: Playback history integration SHALL skip incomplete snapshots safely
Playback history integration SHALL return typed skipped outcomes for playback
snapshots that cannot produce durable history records.

#### Scenario: Snapshot lacks durable media context
- **WHEN** a playback snapshot has no source URI, no duration, a source URI not
  present in the media catalog, or a non-recordable playback lifecycle state
- **THEN** the integration returns a typed skipped outcome and does not write
  playback history or publish history invalidation events

### Requirement: Playback history observer SHALL be attachable by composition roots
The media-library runtime implementation SHALL provide a small observer wrapper
that app composition roots can attach to a playback state observable without
adding UI ownership or concrete player dependencies.

#### Scenario: Composition root attaches observer
- **WHEN** a `PlaybackControllerContract` publishes state snapshots during
  playback
- **THEN** the observer delegates recording to the playback history recorder
  and can be disposed so it stops observing future playback state

### Requirement: Media library smoke gate SHALL validate the Phase C local library flow
The media-library runtime implementation SHALL provide a non-UI smoke gate that
executes the storage-backed local-library flow from local scan through
continue-watching replay.

#### Scenario: Library smoke gate runs
- **WHEN** the smoke gate creates a local media root, scans supported files,
  imports candidates, saves provider bindings, records playback history from a
  `PlaybackStateSnapshot`, loads storage-backed detail data, routes local
  playback handoff, reopens storage, and refreshes the library snapshot
- **THEN** it observes imported catalog items, deterministic detail episodes,
  a successful playback handoff, `HistoryRecorded` and `BindingChanged`
  invalidations, and persisted continue-watching state without requiring
  Flutter UI, concrete player bindings, provider HTTP transports, RSS, BT,
  streaming, network policy, diagnostics, SQLite SQL outside storage
  implementation, or app-shell code

