## ADDED Requirements

### Requirement: Virtual media stream contract SHALL provide timeline-safe buffered projections
The system SHALL expose virtual stream descriptors and buffered range snapshots in a form that timeline overlay contracts can project onto playback timelines without opening files, sockets, HTTP servers, pipe servers, FFI handles, network clients, or libtorrent objects.

#### Scenario: Timeline consumes buffered range state
- **WHEN** a timeline overlay snapshot is composed for a task-backed virtual stream
- **THEN** it can read buffered range snapshots through virtual stream contracts without making stream byte serving depend on timeline overlay behavior
