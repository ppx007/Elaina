## ADDED Requirements

### Requirement: BT task core SHALL expose deterministic runtime orchestration
The BT task core SHALL expose a deterministic runtime or bootstrap surface that wires existing task contracts, download-engine adapter boundaries, BT task storage contracts, optional cache invalidation, lifecycle-safe outcomes, and replayable projections.

#### Scenario: Runtime observes adapter status
- **WHEN** the download-engine adapter emits task status for a known task
- **THEN** the BT task core runtime stores the normalized transfer snapshot and exposes the status through engine-neutral task projections

### Requirement: BT task core SHALL preserve lifecycle-safe runtime behavior
The BT task core SHALL define unavailable, unsupported, failed, ignored, and disposed runtime outcomes for creation, metadata fetch, file selection, lifecycle commands, status observation, event observation, and task projection flows.

#### Scenario: Runtime is disposed
- **WHEN** a caller requests task creation, metadata fetch, task projection, file selection, lifecycle command, status observation, or event observation after disposal
- **THEN** the BT task core returns a lifecycle-safe disposed outcome without invoking the adapter or mutating storage

### Requirement: BT task core SHALL validate Step 18 boundaries
The BT task core SHALL include tests or validation that prove task orchestration does not own virtual media stream serving, piece-priority scheduling, timeline overlay rendering, RSS auto-download, concrete torrent engines, UI screens, diagnostics, network implementations, storage migrations, or native-player bindings.

#### Scenario: Step 18 checker scans runtime files
- **WHEN** BT task core runtime validation runs
- **THEN** forbidden later-step and concrete implementation dependencies are rejected before the runtime is reported ready
