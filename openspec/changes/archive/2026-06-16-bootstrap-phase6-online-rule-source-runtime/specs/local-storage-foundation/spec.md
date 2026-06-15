## MODIFIED Requirements

### Requirement: Local storage foundation SHALL support online rule source runtime evaluation replay
The local storage foundation SHALL allow the online rule source runtime to persist and replay manifest validation results, evaluation snapshots, and unsupported operation records via the existing OnlineRuleRuntimeStore contracts. The runtime SHALL read manifestBySource, evaluationsForSource, and storeManifest from the store to build restart projections without introducing new storage types or migration steps.

#### Scenario: Runtime rebuilds projection from store after restart
- **WHEN** a new runtime instance is created for a scope that has previously stored manifest and evaluation records
- **THEN** the runtime projection reads manifest and evaluation data from the existing rule store contracts without requiring additional storage schema changes

#### Scenario: Runtime persists evaluation decisions on accepted evaluations
- **WHEN** the runtime accepts an evaluation request
- **THEN** the runtime records the evaluation snapshot to the rule store and the runtime projection reflects it on the next snapshot
