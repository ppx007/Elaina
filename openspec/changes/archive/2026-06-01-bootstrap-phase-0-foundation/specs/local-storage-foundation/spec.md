## ADDED Requirements

### Requirement: Storage foundation SHALL provide baseline durable state domains
The system SHALL define storage responsibilities for SQLite metadata, blob cache, media cache, user settings, and migration state before feature-specific consumers are implemented.

#### Scenario: A future feature needs persistence
- **WHEN** playback history, RSS entries, provider state, or diagnostics snapshots need durable storage
- **THEN** the feature stores its state through pre-defined Storage-layer responsibilities instead of creating ad hoc persistence paths

### Requirement: Metadata persistence MUST support schema evolution
The system MUST track schema versioning and provide a migration mechanism for SQLite-backed metadata so future releases can evolve storage safely.

#### Scenario: A later version changes metadata shape
- **WHEN** a new feature introduces a schema change to persisted metadata
- **THEN** the system applies an ordered migration from the previous schema version before using the new structure

### Requirement: Storage concerns MUST remain isolated from UI and provider code
The system MUST isolate persistence and cache implementation details inside the Storage layer so other layers depend on storage contracts rather than concrete database or file layout details.

#### Scenario: A provider needs cached state
- **WHEN** a provider-facing flow needs persisted or cached information
- **THEN** it accesses that information through approved Gateway and Storage-layer contracts instead of direct database, filesystem, or provider-owned cache coupling

### Requirement: Provider cache behavior MUST NOT bypass ProviderGateway
Provider-facing cache, retry, rate-limit, and negative-cache behavior MUST be mediated by `ProviderGateway` even when Storage-layer persistence is used underneath.

#### Scenario: A provider response is cacheable
- **WHEN** a provider-facing request produces cacheable or negative-cacheable data
- **THEN** `ProviderGateway` owns the cache policy and delegates persistence to Storage contracts without the provider directly managing cache files or database rows
