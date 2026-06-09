# playback-state-contract Specification

## Purpose
TBD - created by archiving change playback-state-contract. Update Purpose after archive.
## Requirements
### Requirement: Playback state snapshots SHALL be immutable Dart values
The playback state contract SHALL expose immutable, framework-neutral Dart value types for representing the current playback snapshot.

#### Scenario: Snapshot is created
- **WHEN** playback state is represented for Domain, Playback, or UI consumers
- **THEN** the snapshot contains data values without requiring Flutter widgets, BuildContext values, native handles, streams, provider metadata, storage records, or network clients

### Requirement: Playback state SHALL separate lifecycle status from timeline data
The playback state contract SHALL represent playback lifecycle status independently from timeline position, duration, and update timestamps.

#### Scenario: Playback is paused at a position
- **WHEN** playback is paused with a known position and duration
- **THEN** the snapshot can report paused status without losing timeline position, duration, or timestamp data

### Requirement: Playback state SHALL represent buffering without owning streaming behavior
The playback state contract SHALL expose buffering state as data only and MUST NOT require BT streaming, HTTP buffering engines, HLS internals, network clients, or native player event bindings.

#### Scenario: Playback is buffering
- **WHEN** playback is waiting for buffered media
- **THEN** the snapshot can report buffering status and optional buffered progress without importing streaming, network, native player, or provider implementations

### Requirement: Playback state SHALL represent active tracks with Domain-facing identifiers
The playback state contract SHALL expose active audio and subtitle track selections using Domain-facing track identifiers and MUST NOT expose native-player, provider-local, or UI-local track identifiers.

#### Scenario: Active subtitle changes
- **WHEN** a subtitle track becomes active
- **THEN** the snapshot records the active subtitle track through a Domain-facing track identifier

### Requirement: Playback state observation SHALL be implementation-neutral
The playback state contract SHALL define a minimal observation boundary for receiving state snapshots without requiring Flutter, package-specific state managers, concrete event buses, native player callbacks, or adapter internals.

#### Scenario: Consumer observes playback state
- **WHEN** a future consumer subscribes to playback state changes
- **THEN** it depends on the playback state contract rather than Flutter state management, native playback callbacks, provider systems, streaming systems, gateway, storage, or network layers

### Requirement: Later-phase systems MUST remain outside playback state contract
The playback state contract MUST NOT require provider metadata, advanced subtitle rendering, BT streaming, video enhancement, online rule parsing, VLC fallback, diagnostics integration, Flutter widgets, or native playback bindings. The contract MAY expose framework-neutral basic danmaku overlay snapshot data once Phase 2 basic danmaku runtime is implemented, but it MUST NOT require provider implementations, concrete rendering widgets, Matrix4 effects, gateway, storage, network, or native-player dependencies.

#### Scenario: Playback state contract is validated
- **WHEN** the playback state contract is checked by automation
- **THEN** validation completes without importing or requiring Bangumi, Dandanplay provider implementations, RSS, BT streaming, Anime4K, VLC fallback, online rule runtime, diagnostics center, Flutter, MPV, libmpv, media-kit, gateway, storage, network, or native player code

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

### Requirement: Playback state SHALL expose subtitle snapshot data without concrete runtime dependencies
Playback state contracts SHALL expose subtitle-related snapshot data such as available subtitle tracks, selected subtitle track identity, active cue descriptors, offset, warnings, or failure state using framework-neutral value types.

#### Scenario: Subtitle state is observed
- **WHEN** a playback consumer observes state after subtitles are loaded and a cue is active
- **THEN** the snapshot exposes subtitle data without Flutter widgets, BuildContext, parser implementation types, native player handles, provider clients, storage records, streaming objects, network responses, or diagnostics UI types

### Requirement: Playback state subtitle snapshots SHALL be immutable
Playback state subtitle snapshot values SHALL be immutable or defensively copied so callers cannot mutate runtime-owned track or cue state.

#### Scenario: Snapshot collection is reused
- **WHEN** a caller retains a subtitle state snapshot and the runtime later changes selected subtitle track or active cues
- **THEN** the retained snapshot remains a stable representation of the earlier state

### Requirement: Playback state SHALL expose basic danmaku overlay snapshots
Playback state contracts SHALL expose basic danmaku overlay data such as active frame lanes, clock position, filter state, density policy, and failure state using immutable framework-neutral value types.

#### Scenario: Danmaku state is observed
- **WHEN** a playback consumer observes state after basic danmaku comments are loaded and eligible for the current clock position
- **THEN** the snapshot exposes basic danmaku overlay data without Flutter widgets, BuildContext, provider clients, gateway clients, storage records, network responses, Matrix4 transforms, or native renderer handles

