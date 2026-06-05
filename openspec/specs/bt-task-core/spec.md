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
