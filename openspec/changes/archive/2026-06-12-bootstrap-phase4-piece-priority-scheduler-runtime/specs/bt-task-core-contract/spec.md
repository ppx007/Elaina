## ADDED Requirements

### Requirement: BT task core contract SHALL preserve scheduler-ready metadata
The BT task core contract SHALL persist scheduler-ready task metadata, selected file metadata, file offsets, file lengths, piece length, and lifecycle state so Step 20 can derive file-piece maps through contracts only.

#### Scenario: File selection is replayed for scheduling
- **WHEN** the scheduler runtime starts after task metadata and file selection were persisted
- **THEN** it can derive scheduler inputs from BT task storage contracts without querying a concrete engine

### Requirement: BT task core contract MUST NOT expose engine internals to scheduler runtime
The BT task core contract MUST keep torrent handles, piece managers, engine sessions, FFI objects, sockets, files, native player values, and concrete engine errors out of scheduler runtime inputs.

#### Scenario: Scheduler reads task metadata
- **WHEN** Step 20 runtime reads task and file state
- **THEN** it receives engine-neutral task and file records only
