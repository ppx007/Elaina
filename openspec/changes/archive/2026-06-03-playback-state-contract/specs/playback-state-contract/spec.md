## ADDED Requirements

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
The playback state contract MUST NOT require provider metadata, danmaku rendering, advanced subtitle rendering, BT streaming, video enhancement, online rule parsing, VLC fallback, diagnostics integration, Flutter widgets, or native playback bindings.

#### Scenario: Playback state contract is validated
- **WHEN** the playback state contract is checked by automation
- **THEN** validation completes without importing or requiring Bangumi, Dandanplay, RSS, BT streaming, Anime4K, VLC fallback, online rule runtime, diagnostics center, Flutter, MPV, libmpv, media-kit, or native player code
