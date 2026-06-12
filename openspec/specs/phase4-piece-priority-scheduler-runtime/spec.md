# phase4-piece-priority-scheduler-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase4-piece-priority-scheduler-runtime. Update Purpose after archive.
## Requirements
### Requirement: Phase 4 piece priority scheduler runtime SHALL compose scheduler inputs from persisted state
The system SHALL provide a deterministic PiecePriorityScheduler runtime or bootstrap surface that composes persisted BT task metadata, selected file records, virtual stream descriptors, buffered ranges, playback windows, seek targets, and strategy profiles into scheduler plan requests without querying concrete torrent engines, sockets, files, FFI, native players, UI, or network clients.

#### Scenario: Runtime prepares a scheduler plan request
- **WHEN** a BT task has persisted metadata, a selected file, a virtual stream descriptor, and a strategy profile
- **THEN** the runtime can generate or request a priority plan using only engine-neutral storage and stream contracts

### Requirement: Phase 4 piece priority scheduler runtime SHALL generate deterministic priority plans
The system SHALL generate deterministic priority plans that include first-piece, tail-piece, playback-window, seek-target, and stale-window rules according to the active strategy profile while avoiding pieces already fully represented by buffered range state.

#### Scenario: Playback window advances with buffered pieces
- **WHEN** the runtime plans for a playback window whose leading pieces are already fully buffered
- **THEN** the generated plan excludes fully buffered pieces and prioritizes remaining schedulable pieces using the active profile

### Requirement: Phase 4 piece priority scheduler runtime SHALL expose typed action outcomes
The system SHALL return typed runtime outcomes for plan generation, profile selection, plan lookup, plan application recording, unavailable dependencies, invalid scheduler inputs, stale plans, and disposed runtime state.

#### Scenario: Stream state is unavailable
- **WHEN** a scheduler plan is requested for a missing, closed, failed, or mismatched virtual stream
- **THEN** the runtime returns a typed failure without probing concrete download engine, file, socket, FFI, or native-player APIs

### Requirement: Phase 4 piece priority scheduler runtime SHALL persist replayable scheduler state
The system SHALL persist active profile selection, generated priority plans, ordered plan rules, and latest application outcomes so runtime snapshots can be reconstructed after process restart.

#### Scenario: Runtime restarts after plan generation
- **WHEN** persisted scheduler profile, plan, rule, and application records exist
- **THEN** the runtime can project scheduler state without regenerating plans or contacting a concrete engine

### Requirement: Phase 4 piece priority scheduler runtime SHALL keep plan application adapter-neutral
The system SHALL treat plan application as an adapter boundary that records accepted, rejected, or unavailable outcomes and MUST NOT directly depend on libtorrent, FFI, sockets, HTTP servers, file handles, MPV, VLC, media-kit, platform channels, native players, or UI controls.

#### Scenario: Plan applier is unavailable
- **WHEN** a generated priority plan is applied without a configured adapter boundary
- **THEN** the runtime records an unavailable application outcome and publishes scheduler invalidation without invoking concrete engine APIs

### Requirement: Phase 4 piece priority scheduler runtime SHALL remain Step 20 scoped
The system MUST keep timeline overlay composition, UI task screens, concrete torrent engines, concrete range servers, filesystem byte reads, native playback bindings, RSS automation, online-rule runtime, diagnostics center, network implementation, storage migrations, and Phase 5 playback features outside the Step 20 runtime.

#### Scenario: Boundary validation runs
- **WHEN** Step 20 runtime validation scans scheduler runtime files
- **THEN** forbidden downstream, concrete IO, UI, diagnostics, network, storage migration, and native-player dependencies fail validation

