## ADDED Requirements

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
