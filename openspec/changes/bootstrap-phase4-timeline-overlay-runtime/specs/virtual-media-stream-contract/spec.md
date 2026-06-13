## ADDED Requirements

### Requirement: Timeline input snapshots
Virtual media stream contract SHALL provide overlay-safe input snapshots that include stream identity, length/duration metadata where available, and buffered ranges needed for timeline composition.

#### Scenario: Overlay cannot serve bytes
- **WHEN** timeline overlay runtime consumes a virtual stream snapshot
- **THEN** it SHALL NOT use that snapshot to serve bytes, open ranges, or mutate stream range lifecycle.

### Requirement: Timeline rejection for unavailable stream inputs
Virtual media stream contract SHALL allow timeline overlay runtime to distinguish missing, closed, failed, or incomplete stream inputs as typed composition failures.

#### Scenario: Missing stream produces typed overlay failure
- **WHEN** timeline overlay runtime composes for a stream identifier without a persisted stream snapshot
- **THEN** it SHALL return a typed dependency-unavailable outcome.
