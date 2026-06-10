# media-library-foundation Specification

## Purpose
TBD - created by archiving change bootstrap-detail-library-seasonal. Update Purpose after archive.
## Requirements
### Requirement: Media library SHALL define local media identity and scan contracts
The system SHALL define local media identity, scan candidates, and media item contracts independently of provider metadata, and the scan result SHALL remain importable into a persistent library catalog without requiring provider matching.

#### Scenario: Local scan finds a media file
- **WHEN** a local media scanner discovers a playable file
- **THEN** the file is represented as a media item candidate without requiring provider matching, and it can later be imported into the media library catalog through a storage-backed repository contract

### Requirement: Playback history SHALL support continue-watching state
The system SHALL define playback history and continue-watching contracts backed by Storage-layer responsibilities so persisted playback progress can be queried after restart.

#### Scenario: Playback progress is recorded
- **WHEN** playback progress is saved for a media item
- **THEN** the media library can expose continue-watching state through Domain contracts backed by stored playback history entries

### Requirement: User-confirmed bindings MUST outrank automatic matches
The system MUST preserve user-confirmed provider bindings over automatically generated provider matches, and the binding contract SHALL remain stable when persisted through Storage-layer responsibilities.

#### Scenario: Automatic match conflicts with user binding
- **WHEN** an automatic Bangumi match conflicts with a user-confirmed binding
- **THEN** the user-confirmed binding remains authoritative after persistence and derived views refresh

### Requirement: Media library SHALL persist catalog items and batch imports
The system SHALL define repository contracts for storing, retrieving, listing, updating, and removing media library items, and for importing scan candidates into the catalog with deterministic deduplication and result reporting.

#### Scenario: A scan import creates catalog entries
- **WHEN** a batch of local media scan candidates is imported into the catalog
- **THEN** the repository creates new media library items, skips duplicates deterministically, and reports any failures through an import result contract

### Requirement: Local media values SHALL be usable as playback handoff inputs
Local media identity and scan candidate contracts SHALL carry enough source information for a playback source handoff to prepare local file playback without requiring provider metadata, storage-backed library state, or network access.

#### Scenario: Scan candidate is selected for playback
- **WHEN** a user or test selects a media scan candidate with a file URI
- **THEN** the candidate can be passed to the playback source handoff without resolving Bangumi bindings, provider metadata, playback history, storage records, gateway requests, or network resources

### Requirement: Media library scanner SHALL expose local scan results through Domain media contracts
The media library foundation SHALL expose local scan scopes, results, typed failures, and events through Domain media values before any storage-backed library state or provider metadata is required.

#### Scenario: Local scan completes with candidates
- **WHEN** a local media scan completes with file-backed candidates
- **THEN** the result contains existing `MediaScanCandidate` values and normalized typed failures without requiring database persistence, provider bindings, playback history, gateway requests, network resources, or UI state

### Requirement: Media scan failures SHALL carry typed failure semantics
The media library foundation SHALL provide scan failure semantics that distinguish unsupported schemes, excluded entries, unreadable entries, cancelled scans, and generic discovery failures without requiring callers to parse free-form messages.

#### Scenario: Unsupported entry fails during scan
- **WHEN** a scan entry cannot be represented as a supported local file candidate
- **THEN** the media scan failure identifies the failure category through Domain media data instead of a concrete platform exception or message-only error

### Requirement: Media library state SHALL be consumable by video detail runtime
Media library continue-watching and provider-binding contracts SHALL be consumable by the video detail runtime without requiring media scanning, catalog import, storage implementation details, provider runtime internals, gateway requests, network resources, or UI state.

#### Scenario: Detail runtime reads continue-watching state
- **WHEN** a detail id resolves to local media with playback history
- **THEN** the detail runtime can include continue-watching state from media-library contracts without owning history persistence or playback progress recording

### Requirement: User-confirmed bindings SHALL drive video detail follow state
User-confirmed provider bindings SHALL drive video detail follow state and SHALL outrank automatic bindings when the detail runtime derives follow/unfollow actions.

#### Scenario: Detail binding is user-confirmed
- **WHEN** a local media item has a user-confirmed provider binding for the selected metadata provider
- **THEN** the detail runtime exposes a followed state and does not replace it with lower-confidence automatic metadata matches

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

