## MODIFIED Requirements

### Requirement: Storage foundation SHALL provide baseline durable state domains
The system SHALL define storage responsibilities for SQLite metadata, blob cache, media cache, user settings, migration state, media library catalog state, playback history state, provider binding state, subtitle cache state, and RSS feed state before feature-specific consumers are implemented.

#### Scenario: A future feature needs persistence
- **WHEN** playback history, media library items, subtitle cache records, RSS entries, provider state, or diagnostics snapshots need durable storage
- **THEN** the feature stores its state through pre-defined Storage-layer responsibilities instead of creating ad hoc persistence paths

### Requirement: Storage concerns MUST remain isolated from UI and provider code
The system MUST isolate persistence and cache implementation details inside the Storage layer so other layers depend on storage contracts rather than concrete database or file layout details, including subtitle search/content cache records and RSS feed source/item/cursor/deduplication records.

#### Scenario: A provider needs cached state
- **WHEN** a provider-facing flow needs persisted or cached information
- **THEN** it accesses that information through approved Gateway and Storage-layer contracts instead of direct database, filesystem, or provider-owned cache coupling

## ADDED Requirements

### Requirement: Storage foundation SHALL expose RSS feed persistence contracts
The system SHALL expose storage-backed contracts for registered feed sources, fetched feed items, feed refresh cursor metadata, and accepted feed deduplication keys.

#### Scenario: RSS feed state survives restart
- **WHEN** a feed source is registered, refreshed, and deduplicated
- **THEN** later RSS engine refreshes can read the source, cursor, item, and dedupe state through Storage contracts
