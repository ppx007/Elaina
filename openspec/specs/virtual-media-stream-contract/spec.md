# virtual-media-stream-contract Specification

## Purpose
TBD - created by archiving change virtual-media-stream-contract. Update Purpose after archive.
## Requirements
### Requirement: Virtual media stream contract SHALL persist task-backed stream state
The system SHALL define durable virtual media stream contracts for stream descriptors, lifecycle state, buffered ranges, and latest stream events without exposing concrete download-engine, HTTP server, socket, file, or FFI implementation details.

#### Scenario: Stream state survives restart
- **WHEN** a virtual stream is created for a BT task file and buffered ranges are recorded
- **THEN** later Domain or Playback handoff reads can reconstruct the stream descriptor and buffered range state through Storage contracts

### Requirement: Virtual media stream contract SHALL create streams from persisted BT task metadata
The system SHALL create virtual streams only from engine-neutral BT task metadata and file records that have already been persisted through the BT task core contract.

#### Scenario: BT task metadata is unavailable
- **WHEN** a stream is requested for a BT task whose metadata or file list is not available in Storage
- **THEN** stream creation returns a typed failure without probing a concrete download engine or exposing torrent internals

### Requirement: Virtual media stream contract SHALL orchestrate byte ranges without owning concrete byte serving
The system SHALL expose byte range request, range availability, and buffered range contracts while leaving concrete byte delivery to adapter boundaries.

#### Scenario: Player requests a range
- **WHEN** Playback requests a byte range for a virtual stream
- **THEN** the stream contract resolves the request through virtual stream and Storage abstractions rather than opening files, sockets, HTTP servers, FFI handles, or libtorrent objects

### Requirement: Virtual media stream contract SHALL publish stream invalidation events
The system SHALL publish cache invalidation events when virtual streams are created, buffered ranges change, range requests fail, or streams close.

#### Scenario: Buffered range is recorded
- **WHEN** a virtual stream records newly available bytes for a media range
- **THEN** a stream buffered-range invalidation event is published for playback surfaces and later timeline consumers to refresh derived state

### Requirement: Virtual media stream contract MUST remain scoped to Step 19
The system MUST keep piece priority scheduling, timeline overlay rendering, RSS automation, UI task screens, and concrete engine/network implementations outside the VirtualMediaStream contract slice.

#### Scenario: Phase 4 checker runs
- **WHEN** boundary checks scan Step 19 contracts
- **THEN** no concrete engine implementation, scheduler-specific strategy, timeline overlay, RSS automation, or UI dependency is required by the virtual stream contract

