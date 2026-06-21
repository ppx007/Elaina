## MODIFIED Requirements

### Requirement: BT task core SHALL expose deterministic runtime orchestration
The BT task core SHALL expose a deterministic runtime or bootstrap surface that
wires existing task contracts, download-engine adapter boundaries, BT task
storage contracts, optional cache invalidation, lifecycle-safe outcomes,
replayable projections, and the file/transfer/capability data required by a BT
management UI.

#### Scenario: Runtime projects management data
- **WHEN** the BT task core runtime lists or refreshes tasks
- **THEN** projections include source kind, source URI, lifecycle state,
  timestamps, metadata, info hash, piece length, files, latest transfer
  snapshot, latest event, and latest task message

### Requirement: BT lifecycle SHALL be capability gated
The system SHALL define BT task lifecycle actions in a way that can be hidden,
rejected, or degraded when the platform does not support a capability such as
task management, metadata fetching, virtual streaming, or long background
downloading.

#### Scenario: Download domain exposes management capabilities
- **WHEN** UI consumes the download runtime
- **THEN** it receives task-management, metadata-fetching, virtual-stream, and
  background-download capability availability without inspecting adapter
  internals

#### Scenario: Batch commands skip terminal tasks
- **WHEN** a caller pauses or resumes all tasks through the download domain
- **THEN** the command applies only to tasks whose lifecycle state can be
  changed and reports the first normalized failure if one occurs
