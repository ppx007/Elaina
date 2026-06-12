# piece-priority-scheduler Specification

## Purpose
TBD - created by archiving change bootstrap-bt-streaming-core. Update Purpose after archive.
## Requirements
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

### Requirement: Piece priority scheduler SHALL expose plan application outcomes
The system SHALL expose engine-neutral plan application contracts that report whether a generated priority plan was accepted, rejected, or unavailable without binding to a concrete engine API.

#### Scenario: Plan applier rejects a plan
- **WHEN** the adapter boundary cannot apply a priority plan
- **THEN** the scheduler contract records a typed application failure and does not leak concrete engine error objects

### Requirement: Piece priority scheduler SHALL expose runtime bootstrap projections
The piece priority scheduler capability SHALL expose runtime/bootstrap projections for active profile state, latest generated plan, ordered priority rules, latest application outcome, typed planning failures, and restart visibility.

#### Scenario: Runtime snapshot is requested
- **WHEN** a caller reads scheduler runtime state after profile selection, plan generation, and application recording have been persisted
- **THEN** the capability returns immutable projections reconstructed from scheduler storage contracts

### Requirement: Piece priority scheduler SHALL gate plan generation by stream and task state
The piece priority scheduler capability SHALL reject planning when required BT metadata, selected file state, file-piece maps, virtual stream state, or strategy profile state is unavailable or inconsistent.

#### Scenario: Selected file is missing
- **WHEN** a scheduler plan is requested for a virtual stream whose backing BT file record is missing or skipped
- **THEN** the capability returns a typed file-map failure and does not generate priority rules

### Requirement: Piece priority scheduler SHALL provide timeline-safe priority projections
The piece priority scheduler capability SHALL expose generated plan summaries, priority rule ranges, active profile metadata, and application outcomes as read-only data for later timeline overlays without owning overlay composition or rendering.

#### Scenario: Timeline reads scheduler state later
- **WHEN** a later timeline overlay runtime needs current playback and seek priority windows
- **THEN** it can read scheduler projections without regenerating plans, applying priorities, or importing concrete download-engine objects

