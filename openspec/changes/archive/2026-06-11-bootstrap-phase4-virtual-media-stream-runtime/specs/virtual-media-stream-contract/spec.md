## ADDED Requirements

### Requirement: Virtual media stream contract SHALL separate range availability from byte delivery
The virtual media stream contract SHALL distinguish adapter-neutral range availability and buffered range recording from concrete byte delivery, leaving actual bytes to explicit adapter boundaries rather than sockets, HTTP servers, files, FFI, libtorrent, or native player bindings.

#### Scenario: Runtime ensures a range
- **WHEN** a runtime ensures that a byte range is available for a virtual stream
- **THEN** it records range availability through stream/storage contracts without requiring concrete byte chunks to be served

### Requirement: Virtual media stream contract SHALL normalize range failures
The virtual media stream contract SHALL provide normalized failures for missing stream, wrong stream, closed stream, failed stream, missing task metadata, missing selected file, skipped file, out-of-bounds range, unavailable adapter boundary, and disposed runtime state.

#### Scenario: Range exceeds stream length
- **WHEN** a caller requests a range whose end exceeds the virtual stream length
- **THEN** the contract returns or records a typed range failure without throwing concrete IO, engine, network, or native-player exceptions

### Requirement: Virtual media stream contract SHALL support restart-safe stream lookup
The virtual media stream contract SHALL allow runtime bootstrap code to reconstruct active, closed, failed, and incomplete stream projections from persisted stream records and related BT task state after process restart.

#### Scenario: Runtime restarts with persisted streams
- **WHEN** the virtual stream runtime boots with existing stream records
- **THEN** it can list and look up stream projections without contacting a concrete torrent engine or byte-serving implementation
