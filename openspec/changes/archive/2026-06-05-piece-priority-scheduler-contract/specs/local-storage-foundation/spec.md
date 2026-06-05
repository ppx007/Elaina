## MODIFIED Requirements

### Requirement: Storage foundation SHALL provide baseline durable state domains
The system SHALL define storage responsibilities for SQLite metadata, blob cache, media cache, user settings, migration state, media library catalog state, playback history state, provider binding state, subtitle cache state, RSS feed state, seasonal catalog state, Bangumi match queue state, BT task state, virtual media stream state, and piece priority scheduler state before feature-specific consumers are implemented.

#### Scenario: A future feature needs persistence
- **WHEN** playback history, media library items, subtitle cache records, RSS entries, seasonal entries, BT task entries, virtual stream descriptors, scheduler profiles, priority plans, provider state, or diagnostics snapshots need durable storage
- **THEN** the feature stores its state through pre-defined Storage-layer responsibilities instead of creating ad hoc persistence paths

### Requirement: Storage concerns MUST remain isolated from UI and provider code
The system MUST isolate persistence and cache implementation details inside the Storage layer so other layers depend on storage contracts rather than concrete database or file layout details, including subtitle search/content cache records, RSS feed source/item/cursor/deduplication records, seasonal catalog entries, Bangumi match queue records, BT task records, virtual media stream records, and piece priority scheduler records.

#### Scenario: A provider needs cached state
- **WHEN** a provider-facing flow needs persisted or cached information
- **THEN** it accesses that information through approved Gateway and Storage-layer contracts instead of direct database, filesystem, or provider-owned cache coupling

## ADDED Requirements

### Requirement: Storage foundation SHALL expose piece priority scheduler persistence contracts
The system SHALL expose storage-backed contracts for scheduler strategy profiles, generated priority plans, priority plan rules, and latest plan application events.

#### Scenario: Priority scheduler state survives restart
- **WHEN** a scheduler profile or generated priority plan is written to storage
- **THEN** later scheduler flows can read that state without querying concrete download engines or platform priority APIs
