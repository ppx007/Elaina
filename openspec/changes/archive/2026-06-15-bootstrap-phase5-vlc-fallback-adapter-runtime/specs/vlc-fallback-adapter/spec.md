## ADDED Requirements

### Requirement: VLC fallback adapter runtime SHALL wrap strategy with acceptance layer
The system SHALL ensure that the fallback adapter strategy is accessed through a runtime acceptance layer that gates operations, projects combined in-memory and stored state, and publishes cache invalidation events on state transitions.

#### Scenario: Runtime wraps strategy operations
- **WHEN** UI or domain surfaces need fallback state
- **THEN** they observe it through `FallbackAdapterRuntime` which gates by disposed/unavailable/missing scope/unsupported capability

### Requirement: VLC fallback adapter runtime SHALL project fallback state after selection
The system SHALL expose the selected fallback candidate, hidden capabilities, strategy state, and active configuration through a runtime projection that combines in-memory latest outcomes with stored records.

#### Scenario: Projection shows selection result
- **WHEN** a fallback selection completes successfully
- **THEN** the runtime projection exposes the selected candidate ID, hidden capabilities, strategy state kind, and active configuration
