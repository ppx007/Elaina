## ADDED Requirements

### Requirement: Diagnostics runtime mutations SHALL publish diagnostics invalidation events
The cache invalidation bus SHALL support diagnostics runtime mutations by publishing existing diagnostics invalidation events after schema, event, snapshot, export, retention, or capability state has been stored.

#### Scenario: Snapshot is created by diagnostics runtime
- **WHEN** diagnostics runtime stores a snapshot record
- **THEN** `DiagnosticsSnapshotCreated` is published after the snapshot is visible through storage
