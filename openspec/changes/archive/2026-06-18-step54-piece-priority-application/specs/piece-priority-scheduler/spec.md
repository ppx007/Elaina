## MODIFIED Requirements

### Requirement: Piece priority scheduler SHALL expose plan application outcomes
The system SHALL expose engine-neutral plan application contracts that report
whether a generated priority plan was accepted, rejected, or unavailable
without leaking concrete engine API objects. Concrete Streaming-layer adapters
MAY implement `PiecePriorityPlanApplier`, but callers and persisted scheduler
state SHALL observe only normalized `PiecePriorityApplicationOutcome` values.

#### Scenario: Plan applier rejects a plan
- **WHEN** the adapter boundary cannot apply a priority plan
- **THEN** the scheduler contract records a typed application failure and does
  not leak concrete engine error objects

#### Scenario: Concrete adapter accepts a scheduler plan
- **WHEN** a concrete Streaming adapter applies a generated plan through the
  `PiecePriorityPlanApplier` boundary
- **THEN** the scheduler records an accepted application event using existing
  scheduler storage and cache invalidation contracts, not concrete engine
  handles or UI state
