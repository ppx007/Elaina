## ADDED Requirements

### Requirement: Virtual media stream contract SHALL provide scheduler-safe range state
The system SHALL expose virtual stream descriptors and buffered range snapshots as scheduler inputs without making virtual stream byte serving depend on piece priority planning.

#### Scenario: Scheduler evaluates buffered ranges
- **WHEN** the piece priority scheduler plans a playback or seek window for a virtual stream
- **THEN** it can read descriptor and buffered range state through virtual stream contracts without opening files, sockets, HTTP servers, FFI handles, or libtorrent objects
