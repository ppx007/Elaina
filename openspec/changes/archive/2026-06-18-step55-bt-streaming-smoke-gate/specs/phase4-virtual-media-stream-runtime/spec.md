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

#### Scenario: Smoke gate serves selected file bytes
- **WHEN** Step 55 has selected a BT task file and creates a virtual stream for
  it using the file-backed byte source
- **THEN** opening a valid byte range returns deterministic
  `VirtualByteRangeChunk` values and records buffered range state without
  requiring a UI playback surface or an HTTP/range server
