## ADDED Requirements

### Requirement: Atomic timeline overlay runtime state persistence
Local storage foundation SHALL support atomic persistence boundaries for timeline overlay runtime profiles, active profile mapping, ordered layer preferences, visibility, and latest snapshot metadata.

#### Scenario: Layer configuration persists atomically
- **WHEN** timeline overlay runtime accepts a layer visibility or ordering update
- **THEN** the complete updated layer configuration SHALL be persisted atomically before it is exposed to readers.

### Requirement: Timeline overlay restart reconstruction
Local storage foundation SHALL provide enough persisted overlay state for runtime bootstrap to distinguish configured, unconfigured, missing-profile, rejected-composition, and latest-snapshot states.

#### Scenario: Bootstrap restores latest snapshot metadata
- **WHEN** timeline overlay runtime starts for a stream with persisted snapshot metadata
- **THEN** it SHALL expose that metadata in restart projections without requiring UI state.

### Requirement: Timeline overlay storage boundary enforcement
Timeline overlay runtime SHALL access persisted overlay state through storage contracts and SHALL NOT bypass repository/storage boundaries or depend on concrete database implementations.

#### Scenario: Runtime uses storage abstraction
- **WHEN** runtime reads overlay profiles or layers
- **THEN** it SHALL use the timeline overlay storage contract rather than direct SQL, file, or platform storage APIs.
