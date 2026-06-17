## ADDED Requirements

### Requirement: Concrete storage foundation SHALL persist core local state through SQLite
The system SHALL provide a concrete SQLite-backed storage foundation for core local storage domains needed by Phase C: schema metadata, settings, blob cache entries, media cache ranges, media library catalog records, playback history records, provider bindings, and subtitle cache records.

#### Scenario: Core storage survives restart
- **WHEN** core storage records are written through `SqliteStorageFoundation`
- **THEN** a later `SqliteStorageFoundation` opened against the same database can read those records through the existing `StorageFoundation` contracts

### Requirement: Deterministic storage foundation SHALL remain adapter-free
The system SHALL preserve `DeterministicStorageFoundation` as an in-memory, adapter-free bootstrap implementation even after concrete SQLite storage is introduced.

#### Scenario: Tests request deterministic bootstrap storage
- **WHEN** tests or runtime acceptance layers construct `DeterministicStorageFoundation`
- **THEN** construction does not require SQLite, platform filesystem plugins, remote services, or startup migrations

### Requirement: Concrete storage foundation SHALL delegate out-of-scope feature stores explicitly
The concrete SQLite storage foundation SHALL accept injected stores or deterministic fallback stores for feature-specific domains not implemented in Step 41, provided the core Step 41 domains are SQLite-backed and clearly documented.

#### Scenario: A later Phase 4 store is requested before its concrete adapter exists
- **WHEN** a caller accesses a feature-specific store outside the Step 41 core set
- **THEN** the foundation returns the injected or deterministic fallback store without claiming SQLite persistence for that domain

### Requirement: SQLite schema migration state MUST be explicit
The concrete SQLite storage foundation MUST track schema version state in SQLite and expose it through the existing `MetadataStore` migration contract.

#### Scenario: A migration is applied
- **WHEN** migrations are applied through the SQLite metadata store
- **THEN** the schema version is stored durably and a later database open reports the migrated version
