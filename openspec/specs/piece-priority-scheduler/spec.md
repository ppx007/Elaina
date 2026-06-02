# piece-priority-scheduler Specification

## Purpose
TBD - created by archiving change bootstrap-bt-streaming-core. Update Purpose after archive.
## Requirements
### Requirement: Piece priority scheduler SHALL plan playback-aware priorities
The system SHALL define `PiecePriorityScheduler` contracts that convert playback position, seek targets, and file-piece maps into priority plans.

#### Scenario: Playback window advances
- **WHEN** playback position advances inside a virtual stream
- **THEN** the scheduler produces a priority plan for current and near-future pieces

### Requirement: Piece priority scheduler SHALL support seek target reprioritization
The system SHALL reprioritize pieces around pending seek targets without requiring UI or player code to manipulate piece states directly.

#### Scenario: User seeks ahead
- **WHEN** a seek target is requested
- **THEN** the scheduler raises priority for the target window and can lower stale playback-window priorities

### Requirement: Piece priority scheduler SHALL support strategy profiles
The system SHALL define strategy profile contracts so priority behavior can be adjusted without replacing BT task or virtual stream contracts.

#### Scenario: Profile changes priority strategy
- **WHEN** a profile changes first-piece, tail-piece, or lookahead behavior
- **THEN** the scheduler emits plans using the selected profile while preserving the same public contract

