# bt-task-core Specification

## Purpose
TBD - created by archiving change bootstrap-bt-streaming-core. Update Purpose after archive.
## Requirements
### Requirement: BT task core SHALL define engine-neutral task contracts
The system SHALL define BT task identity, source, metadata, file list, lifecycle state, command contracts, and durable task-state handoff without exposing concrete download-engine APIs to UI or player layers.

#### Scenario: Magnet task is created
- **WHEN** Domain creates a BT task from a magnet or torrent source
- **THEN** the task is represented by engine-neutral contracts, persisted through task storage, and routed through a download-engine adapter boundary

### Requirement: BT task file selection SHALL remain playback aware
The system SHALL expose task file descriptors and selected media files without requiring the player to inspect torrent engine internals, while persisting file selection state for later virtual stream handoff.

#### Scenario: User selects a media file from a BT task
- **WHEN** a playable file is selected from a BT task file list
- **THEN** playback resolves it through virtual stream or playback source contracts rather than concrete torrent file handles, and the selected file state remains durable

### Requirement: BT lifecycle SHALL be capability gated
The system SHALL define BT task lifecycle actions in a way that can be hidden, rejected, or degraded when the platform does not support a capability such as task management, metadata fetching, virtual streaming, or long background downloading.

#### Scenario: Platform has limited background support
- **WHEN** the current platform cannot support long background BT work
- **THEN** Domain capability contracts expose the limitation and lifecycle commands avoid promising unsupported behavior

### Requirement: BT task core SHALL expose a task orchestration contract
The system SHALL expose a Domain-facing contract that coordinates task creation, metadata fetch, status watch, event watch, pause, resume, remove, and file selection through `DownloadEngineAdapter` and Storage contracts.

#### Scenario: Adapter emits task updates
- **WHEN** the download-engine adapter emits task status or metadata events
- **THEN** the orchestration contract persists the normalized task state and exposes replayable Domain status without leaking concrete engine objects

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

