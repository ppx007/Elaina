## ADDED Requirements

### Requirement: Online rule runtime mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when online rule manifests change, validation state changes, target evaluations run, unsupported operations are recorded, page retrieval outcomes are recorded, or source capability state changes.

#### Scenario: Manifest validation changes
- **WHEN** online rule validation records new issues or clears existing issues for a source manifest
- **THEN** an online rule invalidation event is published so derived views and diagnostics snapshots can refresh without direct cross-module mutation
