## MODIFIED Requirements

### Requirement: Local storage foundation SHALL support AV sync guard runtime health and degradation replay
The local storage foundation SHALL allow AV sync guard runtime to persist and replay health transitions and degradation decisions via the existing `AVSyncGuardStore` contracts. The runtime SHALL read `latestHealth` and `degradationHistory` from the guard store to build restart projections without introducing new storage types or migration steps.

#### Scenario: Runtime rebuilds projection from store after restart
- **WHEN** a new runtime instance is created for a scope that has previously stored health and degradation records
- **THEN** the runtime projection reads health and degradation data from the existing guard store contracts without requiring additional storage schema changes

#### Scenario: Runtime persists degradation decisions on accepted requests
- **WHEN** the runtime accepts a degradation request
- **THEN** the underlying deterministic guard records the degradation decision to the guard store, and the runtime projection reflects it on the next snapshot
