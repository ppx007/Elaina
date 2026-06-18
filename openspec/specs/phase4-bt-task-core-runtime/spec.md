# phase4-bt-task-core-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase4-bt-task-core-runtime. Update Purpose after archive.
## Requirements
### Requirement: Phase 4 BT task core runtime SHALL compose engine-neutral task orchestration
The system SHALL provide a BT task core runtime or bootstrap surface that
composes `DownloadEngineAdapter`, `BtTaskStore`, optional cache invalidation,
and existing BT task core contracts without exposing concrete torrent engine
APIs to UI, playback, provider, storage, network, or Domain callers. The runtime
MAY receive concrete adapters through a neutral BT task runtime composition
contract, including the Step 51 libtorrent adapter, while preserving
engine-neutral projections and outcomes.

#### Scenario: Runtime creates a magnet task
- **WHEN** the runtime receives a magnet task creation request and task-management capability is supported
- **THEN** it routes creation through the adapter boundary, persists an engine-neutral task record, records a creation event, publishes optional invalidation, and returns a runtime-safe success result

#### Scenario: Runtime uses concrete BT adapter
- **WHEN** app composition injects the concrete libtorrent adapter through the
  BT task runtime composition contract
- **THEN** runtime projections, storage records, invalidation events, and action
  results remain engine-neutral and do not expose libtorrent plugin values

#### Scenario: Runtime composition observes task state
- **WHEN** a composed runtime observes adapter status or task events
- **THEN** it persists normalized transfer snapshots and events that can be
  replayed after restart without a concrete engine handle

#### Scenario: Runtime participates in BT streaming smoke gate
- **WHEN** Step 55 creates a task through the concrete libtorrent composition
  boundary and ensures metadata for a streamable file
- **THEN** the runtime stores engine-neutral task, metadata, file-selection,
  lifecycle, and event projections that virtual streams and schedulers can
  consume without concrete libtorrent objects

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
The system MUST keep Flutter UI, playback source handoff, concrete range
servers, virtual byte serving, piece-priority application, timeline overlay
rendering, RSS auto-download execution, diagnostics center, WebView, network
policy implementation, storage migration, MPV/VLC/media-kit, and native player
bindings outside the neutral BT task runtime. Step 52 MAY add a neutral runtime
composition contract and a concrete libtorrent composition factory through the
approved adapter surface, but native/libtorrent package imports MUST remain
limited to the approved concrete adapter file and tests.

#### Scenario: Boundary validation runs
- **WHEN** Step 52 runtime validation scans project files
- **THEN** native/libtorrent package imports are allowed only in the approved
  concrete BT adapter file and tests, while neutral streaming contracts remain
  free of concrete engine dependencies
