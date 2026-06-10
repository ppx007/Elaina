## ADDED Requirements

### Requirement: Media library foundation SHALL provide runtime-facing catalog state
The media library foundation SHALL provide runtime-facing state values or projections that combine catalog items with continue-watching and provider-binding information while preserving existing local media identity contracts.

#### Scenario: Runtime projects catalog item state
- **WHEN** a media-library runtime loads catalog items with playback history and provider bindings
- **THEN** the projected state uses existing `MediaLibraryItem`, `ContinueWatchingState`, and `ProviderBinding` contracts instead of provider-specific, UI-specific, storage-specific, playback-specific, or scanner-local models

### Requirement: Media library foundation SHALL support deterministic runtime actions
The media library foundation SHALL support deterministic action/result semantics for scan, import, list, detail, remove, update, record history, save binding, and play-local-media flows.

#### Scenario: Runtime action completes
- **WHEN** a media-library runtime action succeeds, is unavailable, is unsupported, is ignored, or fails
- **THEN** callers receive a normalized Domain media outcome rather than inferring behavior from thrown storage, provider, UI, network, filesystem, playback, or native-player exceptions

### Requirement: Media library foundation SHALL publish cache invalidation for runtime state changes
The media library foundation SHALL publish existing cache invalidation events for imported, updated, removed, history-recorded, and binding-changed media state without introducing a persistent detail cache or storage migration.

#### Scenario: Catalog item is imported
- **WHEN** the media-library runtime imports a new catalog item
- **THEN** it publishes an existing media-library invalidation event containing the media-library item id and local media id without requiring provider metadata, RSS, seasonal matching, BT, online-rule, diagnostics, or native-player behavior

### Requirement: Media library foundation MUST remain provider-neutral during runtime bootstrap
The media library runtime and foundation MUST NOT require provider metadata, Bangumi runtime internals, ProviderGateway internals, subtitle providers, RSS feed sources, seasonal consumers, online rules, or network clients to scan, import, list, bind, or play local media.

#### Scenario: Runtime imports local media without metadata
- **WHEN** a scan candidate has no provider subject id or metadata binding
- **THEN** it can still be imported, listed, and handed off for local playback through media-library contracts
