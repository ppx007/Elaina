## ADDED Requirements

### Requirement: Virtual media stream SHALL expose runtime bootstrap projections
The virtual media stream capability SHALL expose runtime/bootstrap projections for stream descriptors, lifecycle state, buffered ranges, latest range failure state, restart visibility, and playback handoff source values.

#### Scenario: Runtime snapshot is requested
- **WHEN** a caller reads virtual stream runtime state after streams and buffered ranges have been persisted
- **THEN** the capability returns immutable projections reconstructed from storage-backed stream records without requiring concrete byte serving

### Requirement: Virtual media stream SHALL gate stream lifecycle mutations
The virtual media stream capability SHALL gate create, close, fail, and range-recording operations by stream lifecycle so closed or failed streams return typed failures instead of mutating buffered range state.

#### Scenario: Closed stream receives a range request
- **WHEN** range availability is requested for a closed virtual stream
- **THEN** the capability returns a stream-closed failure and records no new buffered range

### Requirement: Virtual media stream SHALL remain scheduler and timeline neutral
The virtual media stream capability SHALL provide descriptors and buffered range snapshots as data for later scheduler and timeline consumers without depending on piece-priority planning or timeline overlay composition.

#### Scenario: Downstream consumer reads range data
- **WHEN** a later scheduler or timeline component reads virtual stream buffered ranges
- **THEN** it consumes immutable stream/range snapshots and does not mutate stream lifecycle or require byte-serving internals
