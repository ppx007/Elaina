## MODIFIED Requirements

### Requirement: Local storage foundation SHALL support RSS auto-download policy runtime evaluation replay
The local storage foundation SHALL allow the RSS auto-download policy runtime to persist and replay evaluation records, accepted candidates, rejected candidates, deduplication keys, and enqueue outcomes via the existing RssAutoDownloadPolicyStore contracts. The runtime SHALL read policyById, evaluationsForItem, acceptedCandidateById, and latestEnqueueOutcome from the store to build restart projections without introducing new storage types or migration steps.

#### Scenario: Runtime rebuilds projection from store after restart
- **WHEN** a new runtime instance is created for a scope that has previously stored policy, evaluation, candidate, and enqueue records
- **THEN** the runtime projection reads evaluation, candidate, and enqueue data from the existing policy store contracts without requiring additional storage schema changes

#### Scenario: Runtime persists evaluation decisions on accepted evaluations
- **WHEN** the runtime accepts an evaluation request
- **THEN** the runtime records the evaluation, stores accepted/rejected candidates, and records deduplication keys to the policy store, and the runtime projection reflects them on the next snapshot
