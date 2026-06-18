# phase4-virtual-media-stream-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase4-virtual-media-stream-runtime. Update Purpose after archive.
## Requirements
### Requirement: Phase 4 virtual media stream runtime SHALL compose selected BT files into virtual streams
The system SHALL provide a virtual media stream runtime or bootstrap surface
that creates, lists, looks up, closes, fails, restarts, and serves selected BT
file-backed virtual stream projections using `VirtualMediaStreamStore`,
`BtTaskStore`, optional cache invalidation, an optional byte source, and
engine-neutral stream descriptors without requiring UI, playback, or concrete
torrent engine dependencies.

#### Scenario: Selected file becomes a virtual stream
- **WHEN** a selected or streaming-target BT task file has persisted metadata
  and a virtual stream is created for it
- **THEN** the runtime stores an active virtual stream record, emits a created
  event, publishes cache invalidation, and exposes a descriptor whose content
  URI can be resolved by the configured content URI resolver

#### Scenario: Runtime serves a byte range
- **WHEN** a caller opens a valid range for an active stream with a configured
  byte source
- **THEN** the runtime returns a stream of `VirtualByteRangeChunk` values and
  persists the buffered range through existing virtual stream storage records

#### Scenario: Smoke gate serves selected file bytes
- **WHEN** Step 55 has selected a BT task file and creates a virtual stream for
  it using the file-backed byte source
- **THEN** opening a valid byte range returns deterministic
  `VirtualByteRangeChunk` values and records buffered range state without
  requiring a UI playback surface or an HTTP/range server

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
The system MUST keep piece-priority scheduling, timeline overlay composition,
HTTP/range servers, pipe servers, sockets, libtorrent, FFI, UI pages,
diagnostics center, RSS auto-download, online-rule runtime, network
implementation, storage migration, MPV/VLC, and native-player bindings outside
the neutral virtual stream runtime. Step 53 MAY add a concrete file-backed byte
source through the virtual byte-source boundary, but filesystem imports MUST
remain limited to the approved concrete byte source file and tests.

#### Scenario: Boundary validation runs
- **WHEN** Step 53 virtual stream validation scans project files
- **THEN** concrete file IO is allowed only in the approved byte source file
  and tests, while runtime and contract code stay adapter-neutral
