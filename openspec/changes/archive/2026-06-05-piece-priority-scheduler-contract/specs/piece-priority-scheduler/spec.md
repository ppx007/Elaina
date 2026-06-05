## MODIFIED Requirements

### Requirement: Piece priority scheduler SHALL plan playback-aware priorities
The system SHALL define `PiecePriorityScheduler` contracts that convert playback position, seek targets, buffered range snapshots, strategy profiles, and file-piece maps into durable priority plans without querying concrete download engines.

#### Scenario: Playback window advances
- **WHEN** playback position advances inside a virtual stream
- **THEN** the scheduler produces and can persist a priority plan for current and near-future pieces using engine-neutral rules

### Requirement: Piece priority scheduler SHALL support seek target reprioritization
The system SHALL reprioritize pieces around pending seek targets without requiring UI, player code, or virtual stream byte-serving code to manipulate piece states directly.

#### Scenario: User seeks ahead
- **WHEN** a seek target is requested
- **THEN** the scheduler raises priority for the target window and can lower stale playback-window priorities through a generated plan

### Requirement: Piece priority scheduler SHALL support strategy profiles
The system SHALL define durable strategy profile contracts so priority behavior can be adjusted and reconstructed without replacing BT task or virtual stream contracts.

#### Scenario: Profile changes priority strategy
- **WHEN** a profile changes first-piece, tail-piece, seek-target, or lookahead behavior
- **THEN** the scheduler emits plans using the selected profile while preserving the same public contract

## ADDED Requirements

### Requirement: Piece priority scheduler SHALL expose plan application outcomes
The system SHALL expose engine-neutral plan application contracts that report whether a generated priority plan was accepted, rejected, or unavailable without binding to a concrete engine API.

#### Scenario: Plan applier rejects a plan
- **WHEN** the adapter boundary cannot apply a priority plan
- **THEN** the scheduler contract records a typed application failure and does not leak concrete engine error objects
