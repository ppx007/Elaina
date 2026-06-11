## ADDED Requirements

### Requirement: Phase 4 BT task core runtime SHALL compose engine-neutral task orchestration
The system SHALL provide a deterministic BT task core runtime or bootstrap surface that composes `DownloadEngineAdapter`, `BtTaskStore`, optional cache invalidation, and existing BT task core contracts without exposing concrete torrent engine APIs to UI, playback, or Domain callers.

#### Scenario: Runtime creates a magnet task
- **WHEN** the runtime receives a magnet task creation request and task-management capability is supported
- **THEN** it routes creation through the adapter boundary, persists an engine-neutral task record, records a creation event, publishes optional invalidation, and returns a runtime-safe success result

### Requirement: Phase 4 BT task core runtime SHALL persist metadata and file state
The system SHALL persist adapter-provided metadata, file descriptors, file offsets, piece length, file selection state, and task lifecycle state through BT task storage contracts.

#### Scenario: Metadata is fetched
- **WHEN** the runtime ensures metadata for an existing task
- **THEN** it stores normalized metadata and file records, updates task lifecycle state, records a metadata event, and exposes replayable metadata without concrete engine objects

### Requirement: Phase 4 BT task core runtime SHALL project replayable task snapshots
The system SHALL expose deterministic runtime snapshots or projections for task records, metadata, files, lifecycle state, latest transfer status, latest event state, runtime availability, and disposed state.

#### Scenario: Domain reads task state after adapter updates
- **WHEN** adapter status or events have been observed and stored
- **THEN** later runtime reads can reconstruct the task projection from storage without subscribing to the concrete download engine

### Requirement: Phase 4 BT task core runtime SHALL gate commands by capability
The system SHALL return typed runtime failures for unsupported task creation, metadata fetching, lifecycle commands, file selection, observation, unavailable adapter/store dependencies, and disposed runtime state.

#### Scenario: Platform does not support task management
- **WHEN** a task creation, pause, resume, remove, or file-selection command is requested on a runtime without task-management capability
- **THEN** the command returns a capability failure and does not promise unsupported background or engine behavior

### Requirement: Phase 4 BT task core runtime SHALL remain Step 18 scoped
The system MUST keep concrete torrent engines, FFI, socket/range servers, virtual byte serving, piece-priority scheduling, timeline overlay rendering, RSS auto-download execution, concrete UI, diagnostics center, network implementation, storage migration, MPV/VLC, and native-player bindings outside the Step 18 runtime.

#### Scenario: Boundary validation runs
- **WHEN** Step 18 runtime validation scans project files
- **THEN** forbidden concrete engine, later Phase 4, Phase 6, UI, diagnostics, network, storage migration, and native-player dependencies fail validation
