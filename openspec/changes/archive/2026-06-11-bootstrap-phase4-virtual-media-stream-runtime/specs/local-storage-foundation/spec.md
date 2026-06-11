## ADDED Requirements

### Requirement: Storage foundation SHALL persist virtual stream runtime state atomically
The storage foundation SHALL provide virtual stream storage contracts that persist stream identity, task/file binding, lifecycle state, buffered ranges, range failure metadata, latest stream event metadata, and updated timestamps as coherent Step 19 runtime transitions.

#### Scenario: Range buffering succeeds
- **WHEN** the virtual stream runtime records an available byte range
- **THEN** storage persists the buffered range and related event before the runtime reports the updated stream projection as replayable

### Requirement: Storage foundation SHALL support virtual stream restart reconstruction
The storage foundation SHALL expose enough persisted virtual stream state for runtime bootstrap code to distinguish active, closed, failed, missing-task, incomplete, and range-failed stream projections after restart.

#### Scenario: Runtime boots after process restart
- **WHEN** persisted virtual stream records exist
- **THEN** the runtime can rebuild stream descriptors, lifecycle projections, buffered ranges, and latest failure state from storage contracts without direct database, filesystem, or engine access

### Requirement: Storage foundation MUST enforce virtual stream storage boundaries
The storage foundation MUST prevent UI, Playback, Provider, concrete torrent engines, piece schedulers, timeline overlays, diagnostics consumers, and native player adapters from bypassing approved virtual stream storage or runtime projection contracts.

#### Scenario: Playback needs stream state
- **WHEN** playback needs a source for a BT-backed file
- **THEN** it reads through virtual stream runtime or playback handoff contracts rather than direct storage tables, filesystem paths, engine sessions, or module-owned caches
