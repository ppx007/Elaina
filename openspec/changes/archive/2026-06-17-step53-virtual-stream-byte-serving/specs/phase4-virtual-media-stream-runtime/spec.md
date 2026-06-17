## MODIFIED Requirements

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
