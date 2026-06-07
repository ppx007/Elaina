## ADDED Requirements

### Requirement: RSS auto-download mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when RSS auto-download policies change, feed items are evaluated, candidates are accepted or rejected, deduplication state changes, or BT enqueue handoff outcomes are recorded.

#### Scenario: Candidate is accepted
- **WHEN** RSS auto-download accepts a feed item as a download candidate
- **THEN** an automation invalidation event is published so derived views and diagnostics snapshots can refresh without direct cross-module mutation
