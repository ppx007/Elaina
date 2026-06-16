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

### Requirement: Virtual media stream contract SHALL provide scheduler-safe range state
The system SHALL expose virtual stream descriptors and buffered range snapshots as scheduler inputs without making virtual stream byte serving depend on piece priority planning.

#### Scenario: Scheduler evaluates buffered ranges
- **WHEN** the piece priority scheduler plans a playback or seek window for a virtual stream
- **THEN** it can read descriptor and buffered range state through virtual stream contracts without opening files, sockets, HTTP servers, FFI handles, or libtorrent objects

### Requirement: Virtual media stream contract SHALL provide timeline-safe buffered projections
The system SHALL expose virtual stream descriptors and buffered range snapshots in a form that timeline overlay contracts can project onto playback timelines without opening files, sockets, HTTP servers, pipe servers, FFI handles, network clients, or libtorrent objects.

#### Scenario: Timeline consumes buffered range state
- **WHEN** a timeline overlay snapshot is composed for a task-backed virtual stream
- **THEN** it can read buffered range snapshots through virtual stream contracts without making stream byte serving depend on timeline overlay behavior

### Requirement: Virtual media stream contract SHALL separate range availability from byte delivery
The virtual media stream contract SHALL distinguish adapter-neutral range availability and buffered range recording from concrete byte delivery, leaving actual bytes to explicit adapter boundaries rather than sockets, HTTP servers, files, FFI, libtorrent, or native player bindings.

#### Scenario: Runtime ensures a range
- **WHEN** a runtime ensures that a byte range is available for a virtual stream
- **THEN** it records range availability through stream/storage contracts without requiring concrete byte chunks to be served

### Requirement: Virtual media stream contract SHALL normalize range failures
The virtual media stream contract SHALL provide normalized failures for missing
stream, wrong stream, closed stream, failed stream, missing task metadata,
missing selected file, skipped selected file, out-of-bounds range, unavailable
adapter boundary, and disposed runtime state. A missing selected file SHALL be
reported as `fileUnavailable`; a selected file explicitly marked skipped SHALL
be reported as `fileSkipped`.

#### Scenario: Skipped selected file is requested
- **WHEN** stream creation is requested for a persisted BT task file whose selection state is skipped
- **THEN** stream creation returns a typed `fileSkipped` failure without probing concrete IO, engine, network, or native-player implementations

### Requirement: Virtual media stream contract SHALL support restart-safe stream lookup
The virtual media stream contract SHALL allow runtime bootstrap code to reconstruct active, closed, failed, and incomplete stream projections from persisted stream records and related BT task state after process restart.

#### Scenario: Runtime restarts with persisted streams
- **WHEN** the virtual stream runtime boots with existing stream records
- **THEN** it can list and look up stream projections without contacting a concrete torrent engine or byte-serving implementation

### Requirement: Virtual media stream contract SHALL provide scheduler input snapshots
The virtual media stream contract SHALL expose descriptor, lifecycle, length, file binding, and buffered range snapshots that Step 20 scheduler planning can consume without owning byte serving or stream lifecycle mutation.

#### Scenario: Scheduler requests stream range state
- **WHEN** a scheduler plan request references a virtual stream id
- **THEN** the contract can provide stream identity, task/file binding, length, lifecycle, and buffered ranges through approved storage-backed projections

### Requirement: Virtual media stream contract SHALL protect stream boundaries from scheduler mutation
The virtual media stream contract MUST prevent scheduler runtime code from closing streams, failing streams, recording range availability, opening byte streams, or invoking concrete byte-serving implementations.

#### Scenario: Scheduler generates a plan
- **WHEN** Step 20 runtime generates priority rules
- **THEN** it reads stream state only and does not mutate stream lifecycle or range availability

### Requirement: Timeline input snapshots
Virtual media stream contract SHALL provide overlay-safe input snapshots that include stream identity, length/duration metadata where available, and buffered ranges needed for timeline composition.

#### Scenario: Overlay cannot serve bytes
- **WHEN** timeline overlay runtime consumes a virtual stream snapshot
- **THEN** it SHALL NOT use that snapshot to serve bytes, open ranges, or mutate stream range lifecycle.

### Requirement: Timeline rejection for unavailable stream inputs
Virtual media stream contract SHALL allow timeline overlay runtime to distinguish missing, closed, failed, or incomplete stream inputs as typed composition failures.

#### Scenario: Missing stream produces typed overlay failure
- **WHEN** timeline overlay runtime composes for a stream identifier without a persisted stream snapshot
- **THEN** it SHALL return a typed dependency-unavailable outcome.

