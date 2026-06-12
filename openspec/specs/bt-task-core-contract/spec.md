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

### Requirement: BT task core contract SHALL provide virtual stream handoff state
The system SHALL expose enough persisted BT task metadata, file selection state, and lifecycle state for virtual media stream creation to proceed without querying concrete download engines directly.

#### Scenario: Virtual stream requests task file state
- **WHEN** the virtual media stream registry creates a stream for a task file
- **THEN** it reads task metadata, selected file records, and lifecycle state through BT task core Storage contracts rather than using adapter-specific torrent objects

### Requirement: BT task core contract SHALL provide scheduler metadata state
The system SHALL expose enough persisted BT task metadata, piece length, file offsets, and selected file records for piece priority planning to proceed without querying concrete download engines directly.

#### Scenario: Scheduler requests task piece state
- **WHEN** the piece priority scheduler plans priorities for a virtual stream file
- **THEN** it reads task metadata, piece length, file offsets, and selected file records through BT task core Storage contracts rather than using adapter-specific torrent objects

### Requirement: BT task core contract SHALL accept engine-neutral RSS automation handoffs
The BT task core contract SHALL define an engine-neutral task creation handoff surface that RSS auto-download can target with accepted candidate metadata, policy identity, source URI, and dedupe key without importing concrete torrent engine APIs.

#### Scenario: RSS candidate requests BT task creation
- **WHEN** RSS auto-download accepts a magnet or torrent candidate
- **THEN** BT task core receives an engine-neutral task creation request through Domain or Streaming contracts rather than a concrete torrent engine call

### Requirement: BT task core contract SHALL provide runtime-safe task projections
The BT task core contract SHALL provide replayable runtime-safe task projections built from persisted task records, metadata records, file records, transfer snapshots, and latest event records.

#### Scenario: Task projection is requested
- **WHEN** a Domain caller requests a known BT task projection
- **THEN** the contract returns engine-neutral task identity, source, lifecycle, metadata, file selection, transfer, and latest event state without exposing adapter-specific torrent objects

### Requirement: BT task core contract SHALL normalize adapter observation side effects
The BT task core contract SHALL normalize adapter status and event streams into storage-backed task updates, metadata updates, transfer snapshots, lifecycle changes, piece completion events, failure events, and optional cache invalidation events.

#### Scenario: Adapter reports task failure
- **WHEN** the adapter emits a task failure event for a known task
- **THEN** the contract persists failed lifecycle state, records a failure event, publishes optional lifecycle invalidation, and exposes the failure through replayable task state

### Requirement: BT task core contract SHALL keep handoff state for later Phase 4 slices
The BT task core contract SHALL persist enough metadata, file offsets, piece length, selected file records, lifecycle state, and transfer/event state for later virtual media stream and piece scheduler work without implementing range serving, piece prioritization, or timeline rendering.

#### Scenario: Later slice reads handoff state
- **WHEN** a later virtual stream or scheduler component requests task file handoff state
- **THEN** it can read the required metadata and selected-file records through BT task core storage contracts rather than concrete engine handles

### Requirement: BT task core contract SHALL preserve selected file metadata for virtual stream bootstrap
The BT task core contract SHALL persist selected file identity, length, offset, selection state, and optional media metadata in a form that virtual media stream contracts can consume deterministically.

#### Scenario: File selection is replayed after restart
- **WHEN** the virtual media stream runtime starts after file selection was persisted
- **THEN** it can determine which files are streamable from BT task storage contracts without querying the download engine

### Requirement: BT task core contract MUST NOT expose engine internals to virtual stream runtime
The BT task core contract MUST keep torrent handles, piece managers, engine sessions, FFI objects, socket servers, and native player values out of virtual stream runtime inputs.

#### Scenario: Stream bootstrap reads task metadata
- **WHEN** Step 19 runtime bootstraps a virtual stream from Step 18 task state
- **THEN** it receives engine-neutral task and file records only

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

