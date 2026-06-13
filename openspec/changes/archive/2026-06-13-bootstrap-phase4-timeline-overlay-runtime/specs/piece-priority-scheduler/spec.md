## ADDED Requirements

### Requirement: Timeline-safe priority projections
Piece priority scheduler SHALL expose generated plan summaries, priority windows, rule byte ranges, active profile metadata, and application outcomes as read-only data for timeline overlay runtime.

#### Scenario: Overlay displays priority windows
- **WHEN** timeline overlay runtime receives scheduler priority windows
- **THEN** it SHALL include them as presentation layers without regenerating scheduler plans.

### Requirement: Scheduler mutation remains outside overlay runtime
Piece priority scheduler plan generation and application SHALL remain owned by scheduler runtime and SHALL NOT be invoked by timeline overlay runtime.

#### Scenario: Overlay cannot apply priority plan
- **WHEN** overlay runtime composes priority layers
- **THEN** it SHALL NOT call plan application APIs or record scheduler application outcomes.
