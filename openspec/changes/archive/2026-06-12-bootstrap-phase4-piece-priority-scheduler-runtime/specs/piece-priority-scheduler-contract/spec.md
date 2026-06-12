## ADDED Requirements

### Requirement: Piece priority scheduler contract SHALL define runtime-safe plan requests
The piece priority scheduler contract SHALL define runtime-safe plan requests that combine task identity, virtual stream identity, active strategy profile, playback window, optional seek target, and persisted buffered range inputs without exposing engine sessions or concrete byte-serving details.

#### Scenario: Playback supplies scheduler input
- **WHEN** playback reports a current byte window and optional seek target for a virtual stream
- **THEN** the scheduler contract accepts those values as data inputs and resolves piece priorities through storage-backed metadata

### Requirement: Piece priority scheduler contract SHALL normalize planning and application failures
The piece priority scheduler contract SHALL provide normalized failures for missing metadata, missing file-piece map, unavailable stream, closed or failed stream, unsupported profile, range out of bounds, no schedulable pieces, missing plan, unavailable applier, adapter rejection, stale plan, and disposed runtime state.

#### Scenario: Plan application is rejected
- **WHEN** an adapter boundary rejects a generated priority plan
- **THEN** the contract records a typed rejection outcome without leaking adapter-specific engine errors

### Requirement: Piece priority scheduler contract SHALL keep application records replayable
The piece priority scheduler contract SHALL persist accepted, rejected, and unavailable application outcomes with enough task, stream, profile, plan, failure, and timestamp metadata for later runtime reads.

#### Scenario: Application outcome is requested after restart
- **WHEN** the runtime restarts after a plan application attempt
- **THEN** it can reconstruct the latest application outcome from scheduler storage contracts
