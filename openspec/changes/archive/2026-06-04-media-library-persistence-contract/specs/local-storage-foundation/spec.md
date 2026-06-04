## MODIFIED Requirements

### Requirement: Storage foundation SHALL provide baseline durable state domains
The system SHALL define storage responsibilities for SQLite metadata, blob cache, media cache, user settings, migration state, media library catalog state, playback history state, and provider binding state before feature-specific consumers are implemented.

#### Scenario: A future feature needs persistence
- **WHEN** playback history, media library items, RSS entries, provider state, or diagnostics snapshots need durable storage
- **THEN** the feature stores its state through pre-defined Storage-layer responsibilities instead of creating ad hoc persistence paths

### Requirement: Storage concerns MUST remain isolated from UI and provider code
The system MUST isolate persistence and cache implementation details inside the Storage layer so other layers depend on storage contracts rather than concrete database or file layout details, including media catalog and history repositories.

#### Scenario: A provider needs cached state
- **WHEN** a provider-facing flow needs persisted or cached information
- **THEN** it accesses that information through approved Gateway and Storage-layer contracts instead of direct database, filesystem, or provider-owned cache coupling

## ADDED Requirements

### Requirement: Storage foundation SHALL expose media persistence repositories
The system SHALL expose storage-backed contracts for the media library catalog, playback history, and provider binding state so Domain consumers can persist and query media state through stable interfaces.

#### Scenario: Media state survives restart
- **WHEN** a media library item, playback history entry, or provider binding is written to storage
- **THEN** a later read through the corresponding repository contract returns the persisted state after application restart
