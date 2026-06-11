## ADDED Requirements

### Requirement: BT task core contract SHALL provide runtime-safe task projections
The BT task core contract SHALL provide replayable runtime-safe task projections built from persisted task records, metadata records, file records, transfer snapshots, and latest event records.

#### Scenario: Task projection is requested
- **WHEN** a Domain caller requests a known BT task projection
- **THEN** the contract returns engine-neutral task identity, source, lifecycle, metadata, file selection, transfer, and latest event state without exposing adapter-specific torrent objects

### Requirement: BT task core contract SHALL normalize adapter observation side effects
The BT task core contract SHALL normalize adapter status and event streams into storage-backed task updates, metadata updates, transfer snapshots, lifecycle changes, piece completion events, failure events, and optional cache invalidation events.

#### Scenario: Adapter reports task failure
- **WHEN** the adapter emits a task failure event for a known task
- **THEN** the contract persists failed lifecycle state, records a failure event, publishes optional lifecycle invalidation, and exposes the failure through replayable task state

### Requirement: BT task core contract SHALL keep handoff state for later Phase 4 slices
The BT task core contract SHALL persist enough metadata, file offsets, piece length, selected file records, lifecycle state, and transfer/event state for later virtual media stream and piece scheduler work without implementing range serving, piece prioritization, or timeline rendering.

#### Scenario: Later slice reads handoff state
- **WHEN** a later virtual stream or scheduler component requests task file handoff state
- **THEN** it can read the required metadata and selected-file records through BT task core storage contracts rather than concrete engine handles
