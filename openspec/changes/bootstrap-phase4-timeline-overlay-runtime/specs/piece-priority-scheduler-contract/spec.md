## ADDED Requirements

### Requirement: Replayable scheduler-derived overlay data
Piece priority scheduler contract SHALL provide replayable priority projection data that timeline overlay runtime can consume after restart.

#### Scenario: Restarted overlay consumes persisted priority rules
- **WHEN** scheduler priority rules were persisted before restart
- **THEN** timeline overlay runtime SHALL be able to compose priority layers from those rules without running scheduler planning.

### Requirement: Overlay read-only scheduler boundary
Piece priority scheduler contract SHALL forbid timeline overlay runtime from generating, rejecting, applying, or mutating scheduler plans.

#### Scenario: Overlay receives stale scheduler projection
- **WHEN** scheduler projection data is stale or unavailable
- **THEN** timeline overlay runtime SHALL return or record an overlay composition outcome without mutating scheduler state.
