# virtual-media-stream Specification

## Purpose
TBD - created by archiving change bootstrap-bt-streaming-core. Update Purpose after archive.
## Requirements
### Requirement: Virtual media stream SHALL expose range-readable media
The system SHALL define `VirtualMediaStream` contracts that expose byte-range reads over task-backed media without exposing torrent pieces to player adapters.

#### Scenario: Player requests a byte range
- **WHEN** a player adapter requests bytes for a media range
- **THEN** the virtual stream resolves the range through stream/storage contracts rather than torrent engine internals

### Requirement: Virtual media stream SHALL report buffered ranges
The system SHALL expose buffered ranges for virtual streams so playback and timeline contracts can represent available media data.

#### Scenario: Buffered ranges are queried
- **WHEN** playback asks what data is available for a virtual stream
- **THEN** the stream reports buffered ranges using stable media identifiers

### Requirement: Virtual media stream MUST preserve player adapter independence
The system MUST keep player adapters dependent on playback/stream abstractions rather than BT task, piece map, or concrete engine objects.

#### Scenario: MPV consumes BT-backed media
- **WHEN** MPV plays media backed by a BT task
- **THEN** it receives a playback-compatible source or stream abstraction without importing BT engine contracts

