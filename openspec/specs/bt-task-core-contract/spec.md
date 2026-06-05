# bt-task-core-contract Specification

## Purpose
Define the durable, engine-neutral BT task core contracts that coordinate Domain orchestration, Storage persistence, adapter command routing, and invalidation events without coupling UI or playback code to concrete download engines.

## Requirements
### Requirement: BT task core SHALL persist engine-neutral task state
The system SHALL define Storage-backed BT task contracts for source, lifecycle, metadata, file selection, transfer status, and latest engine event state without exposing concrete download-engine APIs.

#### Scenario: BT task state survives restart
- **WHEN** a BT task is created, metadata is fetched, files are selected, or transfer status changes
- **THEN** later Domain reads can reconstruct task state through Storage contracts without querying a concrete torrent engine directly

### Requirement: BT task core SHALL orchestrate adapter commands through Domain contracts
The system SHALL define a Domain BT task contract that creates tasks, fetches metadata, replays persisted status, watches adapter updates, and routes pause, resume, remove, and file-selection commands through `DownloadEngineAdapter`.

#### Scenario: Task command is requested
- **WHEN** Domain requests task creation, metadata fetch, pause, resume, remove, or file selection
- **THEN** the request is validated against declared BT capabilities and routed through the adapter boundary while Storage records the resulting task state

### Requirement: BT task core SHALL publish task invalidation events
The system SHALL publish cache invalidation events when BT task lifecycle, metadata, file selection, or removal state changes.

#### Scenario: BT metadata becomes available
- **WHEN** a download engine reports metadata for a task
- **THEN** the task core stores the metadata and publishes a BT metadata invalidation event for derived views to refresh

### Requirement: BT task core MUST remain engine and UI neutral
The system MUST keep concrete torrent engines, sockets, FFI, UI task screens, RSS auto-download rules, virtual byte serving, piece-priority scheduling, and timeline overlay rendering outside the Step 18 BT task core contract.

#### Scenario: Platform cannot support BT work
- **WHEN** a runtime lacks task management, metadata fetching, or long-background download support
- **THEN** the task core exposes capability limitations rather than leaking engine details or promising unsupported UI behavior
