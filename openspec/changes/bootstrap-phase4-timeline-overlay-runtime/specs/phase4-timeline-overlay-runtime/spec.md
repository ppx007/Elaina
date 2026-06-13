## ADDED Requirements

### Requirement: Timeline overlay runtime bootstrap
The system SHALL provide a Phase 4 Step 21 timeline overlay runtime/bootstrap surface that composes immutable timeline snapshots from playback, virtual stream, BT piece, scheduler priority, marker, heat, and persisted layer-profile inputs.

#### Scenario: Compose snapshot from persisted projection inputs
- **WHEN** the runtime receives playback progress, stream duration, buffered ranges, BT piece segments, priority windows, markers, heat values, and an active overlay profile
- **THEN** it SHALL return an immutable timeline overlay snapshot with ordered presentation layers.

#### Scenario: Runtime remains read-only over upstream domains
- **WHEN** the runtime composes a snapshot
- **THEN** it SHALL NOT mutate BT task state, virtual stream lifecycle, scheduler plans, playback state, or byte-serving state.

### Requirement: Timeline overlay action outcomes
The system SHALL expose typed runtime outcomes for composition, profile selection, layer configuration, snapshot lookup, dependency-unavailable inputs, invalid layer state, missing profile, rejected composition, and disposed runtime state.

#### Scenario: Missing profile is normalized
- **WHEN** a timeline overlay action references a profile that is not persisted
- **THEN** the runtime SHALL return a typed missing-profile outcome without composing a snapshot.

#### Scenario: Disposed runtime rejects actions
- **WHEN** a timeline overlay runtime has been disposed
- **THEN** all profile, layer, snapshot, and composition actions SHALL return a typed disposed outcome.

### Requirement: Timeline overlay restart projection
The system SHALL reconstruct restart-safe overlay projections from persisted profile, active profile, ordered layer, and latest snapshot metadata.

#### Scenario: Restart restores presentation state
- **WHEN** the runtime is bootstrapped after restart for a stream with persisted overlay state
- **THEN** it SHALL expose the active profile, ordered layer visibility, and latest snapshot metadata without requiring UI rendering state.

### Requirement: Timeline overlay invalidation ordering
The system SHALL publish timeline overlay invalidation events only after related profile, layer, snapshot, or rejection state is storage-visible.

#### Scenario: Layer change is visible before invalidation
- **WHEN** a layer order or visibility change is accepted
- **THEN** the persisted layer state SHALL be readable before the cache invalidation event is observed.

### Requirement: Timeline overlay runtime scope
The Step 21 runtime SHALL remain a presentation-facing read-model boundary and SHALL exclude UI rendering, gestures, playback control, BT mutation, scheduler mutation, concrete IO, native player integration, diagnostics behavior, and Phase 5 features.

#### Scenario: Boundary checker rejects UI and native leakage
- **WHEN** validation scans the Step 21 runtime, tests, and checker surfaces
- **THEN** it SHALL fail if those surfaces contain Flutter UI, concrete IO, native player, scheduler mutation, diagnostics, or later-phase runtime dependencies.
