## ADDED Requirements

### Requirement: Player core runtime SHALL own playback state observation wiring
The player core runtime SHALL expose playback state observation through the existing playback state contract and MUST NOT require Flutter state managers, native callback types, provider metadata, storage records, streaming engines, gateway clients, or network clients.

#### Scenario: Runtime playback state changes
- **WHEN** a runtime playback command changes lifecycle, timeline, track, buffering, source, or failure state
- **THEN** observers receive an immutable `PlaybackStateSnapshot` through the playback state observation boundary

### Requirement: Runtime state snapshots SHALL use normalized player-core identifiers
Playback state snapshots emitted by player core runtime SHALL use normalized source, track, and lifecycle identifiers rather than native player or UI-local identifiers.

#### Scenario: Subtitle track changes
- **WHEN** player core runtime switches the active subtitle track
- **THEN** the emitted playback state snapshot records the selected track with a normalized track identifier
