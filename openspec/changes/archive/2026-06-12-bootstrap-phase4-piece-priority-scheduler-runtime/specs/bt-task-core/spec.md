## ADDED Requirements

### Requirement: BT task core SHALL provide scheduler handoff inputs
The BT task core capability SHALL expose persisted task metadata, piece length, selected file records, file offsets, file lengths, lifecycle state, and latest transfer state needed by Step 20 scheduler planning without exposing concrete engine sessions, torrent handles, or piece managers.

#### Scenario: Scheduler derives a file-piece map
- **WHEN** the scheduler plans priorities for a task-backed virtual stream
- **THEN** BT task state provides piece length, file offset, file length, file index, and selection state through engine-neutral storage or runtime projections

### Requirement: BT task core SHALL distinguish non-schedulable task states
The BT task core capability SHALL make failed, removed, metadata-incomplete, missing, and skipped-file states distinguishable to scheduler callers as typed non-schedulable outcomes.

#### Scenario: Task metadata is incomplete
- **WHEN** the scheduler requests planning inputs for a task without persisted metadata or piece length
- **THEN** BT task state is sufficient for a typed metadata-unavailable outcome without querying a download engine
