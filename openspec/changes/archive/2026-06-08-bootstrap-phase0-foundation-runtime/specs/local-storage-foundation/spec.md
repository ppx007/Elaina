## ADDED Requirements

### Requirement: Storage foundation SHALL provide deterministic Phase 0 composition
The system SHALL provide a deterministic `StorageFoundation` composition that exposes existing local store contracts through a single bootstrap surface without requiring concrete database, blob-cache, filesystem, platform, or migration adapters.

#### Scenario: Bootstrap storage is requested
- **WHEN** Phase 0 foundation runtime bootstrap creates storage dependencies
- **THEN** callers can access deterministic metadata, settings, media library, playback history, provider binding, RSS, automation, streaming, network policy, diagnostics, and advanced playback stores through the `StorageFoundation` interface

### Requirement: Storage bootstrap MUST remain local-first and adapter-free
The storage bootstrap MUST NOT introduce concrete SQLite drivers, remote storage, cloud sync, telemetry persistence, platform filesystem plugins, or mandatory startup migrations.

#### Scenario: Durable adapter is unavailable
- **WHEN** no production database or blob adapter has been configured
- **THEN** the deterministic storage foundation remains constructible for tests and early runtime checks without external services
