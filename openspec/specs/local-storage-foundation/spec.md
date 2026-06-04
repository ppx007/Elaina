# local-storage-foundation Specification

## Purpose
TBD - created by archiving change bootstrap-phase-0-foundation. Update Purpose after archive.
## Requirements
### Requirement: Storage foundation SHALL provide baseline durable state domains
The system SHALL define storage responsibilities for SQLite metadata, blob cache, media cache, user settings, migration state, media library catalog state, playback history state, provider binding state, subtitle cache state, and RSS feed state before feature-specific consumers are implemented.

#### Scenario: A future feature needs persistence
- **WHEN** playback history, media library items, subtitle cache records, RSS entries, provider state, or diagnostics snapshots need durable storage
- **THEN** the feature stores its state through pre-defined Storage-layer responsibilities instead of creating ad hoc persistence paths

### Requirement: Metadata persistence MUST support schema evolution
The system MUST track schema versioning and provide a migration mechanism for SQLite-backed metadata so future releases can evolve storage safely.

#### Scenario: A later version changes metadata shape
- **WHEN** a new feature introduces a schema change to persisted metadata
- **THEN** the system applies an ordered migration from the previous schema version before using the new structure

### Requirement: Storage concerns MUST remain isolated from UI and provider code
The system MUST isolate persistence and cache implementation details inside the Storage layer so other layers depend on storage contracts rather than concrete database or file layout details, including subtitle search/content cache records and RSS feed source/item/cursor/deduplication records.

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

