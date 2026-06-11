## ADDED Requirements

### Requirement: Phase 4 virtual media stream runtime SHALL compose selected BT files into virtual streams
The system SHALL provide a deterministic virtual media stream runtime or bootstrap surface that creates virtual stream descriptors from persisted BT task metadata and selected BT file records without probing concrete torrent engines, byte servers, file handles, native players, UI, or network clients.

#### Scenario: Runtime creates a stream for a selected file
- **WHEN** a BT task has persisted metadata and a selected file record
- **THEN** the runtime creates or reuses a virtual stream descriptor containing stable stream id, task id, file index, length, optional content URI, and optional media type through approved storage and stream contracts

### Requirement: Phase 4 virtual media stream runtime SHALL expose typed action outcomes
The system SHALL return typed runtime outcomes for stream creation, lookup, range availability, buffered range recording, close, failure, unavailable dependencies, and disposed runtime state.

#### Scenario: Metadata is missing
- **WHEN** a stream is requested for a task whose metadata or file list is unavailable
- **THEN** the runtime returns a typed failure and does not call concrete torrent engine, filesystem, HTTP server, socket, FFI, or native player APIs

### Requirement: Phase 4 virtual media stream runtime SHALL persist replayable range state
The system SHALL persist stream lifecycle, buffered byte ranges, latest range failures, and range event metadata so later reads can reconstruct virtual stream snapshots across process restarts.

#### Scenario: Range availability is recorded
- **WHEN** a runtime records that a byte range is available or failed for a virtual stream
- **THEN** storage records the range or failure event before the runtime exposes the updated snapshot or publishes invalidation

### Requirement: Phase 4 virtual media stream runtime SHALL provide playback handoff projections
The system SHALL expose playback-safe virtual stream source projections that can be consumed by playback source handoff without exposing BT task internals, piece maps, scheduler plans, timeline overlays, concrete byte-serving details, or native player bindings.

#### Scenario: Playback prepares a virtual stream source
- **WHEN** playback source handoff receives a virtual stream projection from the runtime
- **THEN** it prepares a playback-compatible source that references only the virtual stream abstraction

### Requirement: Phase 4 virtual media stream runtime SHALL remain Step 19 scoped
The system MUST keep piece-priority scheduling, timeline overlay composition, concrete range servers, pipe servers, sockets, filesystem byte reads, libtorrent, FFI, UI pages, diagnostics center, RSS auto-download, online-rule runtime, network implementation, storage migration, MPV/VLC, and native-player bindings outside the Step 19 runtime.

#### Scenario: Boundary validation runs
- **WHEN** Step 19 runtime validation scans project files
- **THEN** forbidden downstream, concrete IO, UI, diagnostics, network, storage migration, and native-player dependencies fail validation
