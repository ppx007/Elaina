## ADDED Requirements

### Requirement: Immutable runtime snapshots
Timeline overlay contract SHALL expose immutable runtime snapshots derived from playback, virtual stream, BT piece, scheduler, marker, heat, and persisted profile inputs.

#### Scenario: Snapshot collections cannot be mutated by callers
- **WHEN** a caller receives a timeline overlay runtime snapshot
- **THEN** layer, marker, piece, heat, and priority collections SHALL be immutable to the caller.

### Requirement: Runtime composition failure normalization
Timeline overlay contract SHALL normalize missing duration, invalid stream length, duplicate layer identifiers, missing profile, dependency-unavailable, and disposed states into typed failures.

#### Scenario: Duplicate layer identifiers are rejected
- **WHEN** runtime composition receives duplicate layer identifiers
- **THEN** it SHALL return a typed invalid-layer failure and persist a composition rejection record where applicable.

### Requirement: Runtime profile and layer persistence
Timeline overlay contract SHALL persist overlay profiles, active profile per stream, ordered layer preferences, visibility, and latest snapshot metadata as overlay-safe presentation state.

#### Scenario: Active profile survives restart
- **WHEN** a stream has an active overlay profile persisted before restart
- **THEN** runtime bootstrap SHALL restore that active profile for subsequent snapshot composition.

### Requirement: Step 21 boundary protection
Timeline overlay contract SHALL keep rendering, gestures, playback control, BT task mutation, scheduler mutation, native player integration, diagnostics behavior, and Phase 5 features outside Step 21 runtime contracts.

#### Scenario: Runtime cannot execute seek
- **WHEN** a user-facing layer later requests a seek from a timeline position
- **THEN** Step 21 runtime SHALL expose only read-model data and SHALL NOT execute playback seek commands.
