# virtual-media-stream Specification

## Purpose
TBD - created by archiving change bootstrap-bt-streaming-core. Update Purpose after archive.
## Requirements
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

### Requirement: Virtual media stream registry SHALL create deterministic task-file streams
The system SHALL provide a deterministic virtual stream registry contract that creates stream descriptors from persisted BT task ids and file indexes, and returns typed failures when the task, metadata, or file selection state is unavailable.

#### Scenario: Stream is created for a selected BT file
- **WHEN** a BT task has persisted metadata and a selected file record
- **THEN** the registry creates a virtual stream descriptor that references the task id, file index, length, and optional content metadata without exposing engine internals

### Requirement: Virtual media stream SHALL expose runtime bootstrap projections
The virtual media stream capability SHALL expose runtime/bootstrap projections for stream descriptors, lifecycle state, buffered ranges, latest range failure state, restart visibility, and playback handoff source values.

#### Scenario: Runtime snapshot is requested
- **WHEN** a caller reads virtual stream runtime state after streams and buffered ranges have been persisted
- **THEN** the capability returns immutable projections reconstructed from storage-backed stream records without requiring concrete byte serving

### Requirement: Virtual media stream SHALL gate stream lifecycle mutations
The virtual media stream capability SHALL gate create, close, fail, and range-recording operations by stream lifecycle so closed or failed streams return typed failures instead of mutating buffered range state.

#### Scenario: Closed stream receives a range request
- **WHEN** range availability is requested for a closed virtual stream
- **THEN** the capability returns a stream-closed failure and records no new buffered range

### Requirement: Virtual media stream SHALL remain scheduler and timeline neutral
The virtual media stream capability SHALL provide descriptors and buffered range snapshots as data for later scheduler and timeline consumers without depending on piece-priority planning or timeline overlay composition.

#### Scenario: Downstream consumer reads range data
- **WHEN** a later scheduler or timeline component reads virtual stream buffered ranges
- **THEN** it consumes immutable stream/range snapshots and does not mutate stream lifecycle or require byte-serving internals

### Requirement: Virtual media stream SHALL provide scheduler-safe stream projections
The virtual media stream capability SHALL provide scheduler-safe stream descriptors, lifecycle state, file binding, media length, and buffered range snapshots as immutable data inputs for Step 20 planning.

#### Scenario: Scheduler evaluates a virtual stream
- **WHEN** the scheduler plans for a virtual stream
- **THEN** it reads descriptor and buffered range projections without mutating stream lifecycle or serving bytes

### Requirement: Virtual media stream SHALL separate scheduler planning from range availability
The virtual media stream capability SHALL allow scheduler planning to consume buffered ranges while keeping range availability, range failures, and byte delivery owned by virtual stream contracts and adapter boundaries.

#### Scenario: Scheduler sees buffered ranges
- **WHEN** buffered ranges already cover a piece fully
- **THEN** scheduler planning can avoid that piece without modifying buffered range records

