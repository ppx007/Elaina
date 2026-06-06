# local-storage-foundation Specification

## Purpose
TBD - created by archiving change bootstrap-phase-0-foundation. Update Purpose after archive.
## Requirements
### Requirement: Storage foundation SHALL provide baseline durable state domains
The system SHALL define storage responsibilities for SQLite metadata, blob cache, media cache, user settings, migration state, media library catalog state, playback history state, provider binding state, subtitle cache state, RSS feed state, seasonal catalog state, Bangumi match queue state, BT task state, virtual media stream state, and piece priority scheduler state before feature-specific consumers are implemented.

#### Scenario: A future feature needs persistence
- **WHEN** playback history, media library items, subtitle cache records, RSS entries, seasonal entries, BT task entries, virtual stream descriptors, scheduler profiles, priority plans, provider state, or diagnostics snapshots need durable storage
- **THEN** the feature stores its state through pre-defined Storage-layer responsibilities instead of creating ad hoc persistence paths

### Requirement: Metadata persistence MUST support schema evolution
The system MUST track schema versioning and provide a migration mechanism for SQLite-backed metadata so future releases can evolve storage safely.

#### Scenario: A later version changes metadata shape
- **WHEN** a new feature introduces a schema change to persisted metadata
- **THEN** the system applies an ordered migration from the previous schema version before using the new structure

### Requirement: Storage concerns MUST remain isolated from UI and provider code
The system MUST isolate persistence and cache implementation details inside the Storage layer so other layers depend on storage contracts rather than concrete database or file layout details, including subtitle search/content cache records, RSS feed source/item/cursor/deduplication records, seasonal catalog entries, Bangumi match queue records, BT task records, virtual media stream records, and piece priority scheduler records.

#### Scenario: A provider needs cached state
- **WHEN** a provider-facing flow needs persisted or cached information
- **THEN** it accesses that information through approved Gateway and Storage-layer contracts instead of direct database, filesystem, or provider-owned cache coupling

### Requirement: Storage foundation SHALL expose media persistence repositories
The system SHALL expose storage-backed contracts for the media library catalog, playback history, and provider binding state so Domain consumers can persist and query media state through stable interfaces.

#### Scenario: Media state survives restart
- **WHEN** a media library item, playback history entry, or provider binding is written to storage
- **THEN** a later read through the corresponding repository contract returns the persisted state after application restart

### Requirement: Provider cache behavior MUST NOT bypass ProviderGateway
Provider-facing cache, retry, rate-limit, and negative-cache behavior MUST be mediated by `ProviderGateway` even when Storage-layer persistence is used underneath.

#### Scenario: A provider response is cacheable
- **WHEN** a provider-facing request produces cacheable or negative-cacheable data
- **THEN** `ProviderGateway` owns the cache policy and delegates persistence to Storage contracts without the provider directly managing cache files or database rows

### Requirement: Storage foundation SHALL expose subtitle cache contracts
The system SHALL expose storage-backed contracts for subtitle search result cache records and retrieved subtitle content cache records.

#### Scenario: Subtitle cache state survives restart
- **WHEN** subtitle search results or retrieved subtitle content are written to storage
- **THEN** a later read through subtitle cache contracts can return the stored data until its TTL expires

### Requirement: Storage foundation SHALL expose RSS feed persistence contracts
The system SHALL expose storage-backed contracts for registered feed sources, fetched feed items, feed refresh cursor metadata, and accepted feed deduplication keys.

#### Scenario: RSS feed state survives restart
- **WHEN** a feed source is registered, refreshed, and deduplicated
- **THEN** later RSS engine refreshes can read the source, cursor, item, and dedupe state through Storage contracts

### Requirement: Storage foundation SHALL expose seasonal indexer persistence contracts
The system SHALL expose storage-backed contracts for seasonal catalog entries, Bangumi match queue items, provider match candidates, and queue processing state.

#### Scenario: Seasonal queue state survives restart
- **WHEN** seasonal catalog entries and queued Bangumi match candidates are written to storage
- **THEN** later seasonal indexing and match worker flows can resume through Storage contracts without Provider-owned persistence

### Requirement: Storage foundation SHALL expose BT task persistence contracts
The system SHALL expose storage-backed contracts for BT task source records, metadata records, file selection records, transfer status snapshots, and latest task events.

#### Scenario: BT task state survives restart
- **WHEN** a BT task is created, metadata is fetched, file selections change, or lifecycle status updates
- **THEN** later BT task orchestration can resume from Storage contracts without relying on provider-owned or engine-owned persistence

### Requirement: Storage foundation SHALL expose virtual media stream persistence contracts
The system SHALL expose storage-backed contracts for virtual stream descriptors, stream lifecycle state, buffered range snapshots, and latest stream range events.

#### Scenario: Virtual stream state survives restart
- **WHEN** a virtual stream descriptor or buffered range is written to storage
- **THEN** later playback handoff and stream registry flows can read that state without querying concrete download engines or byte-serving implementations

### Requirement: Storage foundation SHALL expose piece priority scheduler persistence contracts
The system SHALL expose storage-backed contracts for scheduler strategy profiles, generated priority plans, priority plan rules, and latest plan application events.

#### Scenario: Priority scheduler state survives restart
- **WHEN** a scheduler profile or generated priority plan is written to storage
- **THEN** later scheduler flows can read that state without querying concrete download engines or platform priority APIs

### Requirement: Storage foundation SHALL expose AV sync guard persistence contracts
The system SHALL expose storage-backed contracts for AV sync guard policy configuration, latest health state, sample history metadata, and degradation decision history.

#### Scenario: AV sync guard state survives restart
- **WHEN** AV sync policy, health, sample metadata, or degradation decisions are written to Storage
- **THEN** later Playback flows can restore deterministic guard state without direct database, renderer, native plugin, diagnostics, or UI persistence coupling

