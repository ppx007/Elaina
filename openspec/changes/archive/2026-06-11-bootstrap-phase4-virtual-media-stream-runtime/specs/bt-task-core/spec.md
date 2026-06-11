## ADDED Requirements

### Requirement: BT task core SHALL provide virtual stream handoff inputs
The BT task core capability SHALL expose persisted metadata and selected file records that are sufficient for the Step 19 virtual media stream runtime to create stream descriptors without accessing concrete torrent engine state.

#### Scenario: Selected BT file becomes streamable
- **WHEN** a BT task has metadata and a selected or streaming-target file record
- **THEN** virtual stream creation can read task id, file index, file length, offset, path metadata, and optional media type through BT task storage or runtime projections

### Requirement: BT task core SHALL reject virtual stream creation for non-streamable task state
The BT task core capability SHALL make removed, failed, missing, metadata-incomplete, or skipped-file task states distinguishable to virtual stream runtime callers as typed non-streamable outcomes.

#### Scenario: Task was removed
- **WHEN** virtual stream runtime checks a removed BT task
- **THEN** BT task state is sufficient for the runtime to return a typed task-unavailable or task-failed outcome without probing an engine session
