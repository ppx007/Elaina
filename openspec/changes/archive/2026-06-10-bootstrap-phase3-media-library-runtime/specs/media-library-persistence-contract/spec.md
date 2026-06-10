## ADDED Requirements

### Requirement: Persistence contracts SHALL support runtime catalog operations
Media-library persistence contracts SHALL support deterministic runtime store, find, list, update, remove, and count operations through `MediaLibraryCatalogRepository` without requiring concrete database or storage implementation details.

#### Scenario: Runtime updates catalog item
- **WHEN** the media-library runtime updates or removes a catalog item
- **THEN** the operation is expressed through repository contracts and cache invalidation events without requiring SQLite migrations, blob cache behavior, provider metadata, UI widgets, network clients, or native-player bindings

### Requirement: Persistence contracts SHALL support deterministic runtime batch import
Media-library persistence contracts SHALL support runtime batch import of scan candidates with deterministic imported, skipped-duplicate, and failed outcomes.

#### Scenario: Runtime imports duplicates
- **WHEN** runtime import receives candidates that duplicate existing catalog items by URI or fingerprint
- **THEN** the import contract reports skipped duplicates or duplicate conflicts through typed `MediaImportResult` outcomes rather than creating duplicate catalog entries

### Requirement: Playback history persistence contracts SHALL feed runtime continue-watching state
Playback history contracts SHALL provide latest-entry and continue-watching projections that the media-library runtime can expose in catalog state.

#### Scenario: Runtime loads continue watching
- **WHEN** playback history contains multiple entries across local media items
- **THEN** the runtime can expose sorted continue-watching state through `PlaybackHistoryStore` without querying provider metadata, player internals, UI state, storage implementation details, or network resources

### Requirement: Provider binding persistence contracts SHALL preserve runtime binding precedence
Provider binding contracts SHALL preserve user-confirmed binding precedence when the media-library runtime reads, saves, or derives binding state.

#### Scenario: Automatic binding conflicts with user binding
- **WHEN** the runtime evaluates an automatic binding candidate for a media item that already has a user-confirmed binding
- **THEN** the user-confirmed binding remains authoritative and lower-confidence automatic binding state does not replace it
