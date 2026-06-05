## MODIFIED Requirements

### Requirement: Virtual media stream SHALL expose range-readable media
The system SHALL define `VirtualMediaStream` contracts that expose byte-range reads over task-backed media through virtual stream, Storage, and adapter-boundary contracts without exposing torrent pieces, concrete byte servers, file handles, or download-engine objects to player adapters.

#### Scenario: Player requests a byte range
- **WHEN** a player adapter requests bytes for a media range
- **THEN** the virtual stream resolves the range through stream/storage contracts rather than torrent engine internals, concrete HTTP servers, sockets, files, FFI, or libtorrent bindings

### Requirement: Virtual media stream SHALL report buffered ranges
The system SHALL expose and persist buffered ranges for virtual streams so playback and later timeline contracts can represent available media data across process restarts.

#### Scenario: Buffered ranges are queried
- **WHEN** playback asks what data is available for a virtual stream
- **THEN** the stream reports buffered ranges using stable media identifiers and Storage-backed byte range records

### Requirement: Virtual media stream MUST preserve player adapter independence
The system MUST keep player adapters dependent on playback/stream abstractions rather than BT task, piece map, scheduler, timeline, or concrete engine objects.

#### Scenario: MPV consumes BT-backed media
- **WHEN** MPV plays media backed by a BT task
- **THEN** it receives a playback-compatible source or stream abstraction without importing BT task core, piece scheduler, timeline overlay, or download-engine contracts

## ADDED Requirements

### Requirement: Virtual media stream registry SHALL create deterministic task-file streams
The system SHALL provide a deterministic virtual stream registry contract that creates stream descriptors from persisted BT task ids and file indexes, and returns typed failures when the task, metadata, or file selection state is unavailable.

#### Scenario: Stream is created for a selected BT file
- **WHEN** a BT task has persisted metadata and a selected file record
- **THEN** the registry creates a virtual stream descriptor that references the task id, file index, length, and optional content metadata without exposing engine internals
