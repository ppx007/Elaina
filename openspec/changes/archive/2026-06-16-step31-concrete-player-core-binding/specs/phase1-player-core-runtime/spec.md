## MODIFIED Requirements

### Requirement: Player core runtime SHALL remain native-binding optional
The default player core runtime SHALL run without MPV, libmpv, media-kit, VLC,
platform channels, or video surface rendering while still exercising supported
and unsupported adapter paths through deterministic bindings. The runtime SHALL
also support an explicitly constructed concrete MPV binding path for local file
playback when the concrete backend is available, without making that backend
mandatory for tests, unsupported flows, or non-playback runtime slices.

#### Scenario: Native binding is unavailable
- **WHEN** no concrete native player binding is supplied
- **THEN** the runtime remains constructible and reports unsupported executable
  playback capabilities explicitly

#### Scenario: Concrete binding is supplied
- **WHEN** a concrete MPV binding is supplied for player-core runtime
- **THEN** local file playback, play/pause, seek, stop, and disposal can execute
  through `PlayerCoreRuntime.bound(...)` while unsupported source and track
  capabilities remain normalized
