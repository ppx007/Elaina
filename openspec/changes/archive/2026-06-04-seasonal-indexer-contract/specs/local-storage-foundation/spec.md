## MODIFIED Requirements

### Requirement: Storage foundation SHALL provide baseline durable state domains
The system SHALL define storage responsibilities for SQLite metadata, blob cache, media cache, user settings, migration state, media library catalog state, playback history state, provider binding state, subtitle cache state, RSS feed state, seasonal catalog state, and Bangumi match queue state before feature-specific consumers are implemented.

#### Scenario: A future feature needs persistence
- **WHEN** playback history, media library items, subtitle cache records, RSS entries, seasonal entries, provider state, or diagnostics snapshots need durable storage
- **THEN** the feature stores its state through pre-defined Storage-layer responsibilities instead of creating ad hoc persistence paths

### Requirement: Storage concerns MUST remain isolated from UI and provider code
The system MUST isolate persistence and cache implementation details inside the Storage layer so other layers depend on storage contracts rather than concrete database or file layout details, including subtitle search/content cache records, RSS feed source/item/cursor/deduplication records, seasonal catalog entries, and Bangumi match queue records.

#### Scenario: A provider needs cached state
- **WHEN** a provider-facing flow needs persisted or cached information
- **THEN** it accesses that information through approved Gateway and Storage-layer contracts instead of direct database, filesystem, or provider-owned cache coupling

## ADDED Requirements

### Requirement: Storage foundation SHALL expose seasonal indexer persistence contracts
The system SHALL expose storage-backed contracts for seasonal catalog entries, Bangumi match queue items, provider match candidates, and queue processing state.

#### Scenario: Seasonal queue state survives restart
- **WHEN** seasonal catalog entries and queued Bangumi match candidates are written to storage
- **THEN** later seasonal indexing and match worker flows can resume through Storage contracts without Provider-owned persistence
