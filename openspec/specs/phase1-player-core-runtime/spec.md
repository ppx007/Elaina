# phase1-player-core-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase1-player-core-runtime. Update Purpose after archive.
## Requirements
### Requirement: Phase 1 player core runtime SHALL compose Step 5-8 surfaces
The system SHALL provide a Phase 1 player core runtime that composes MPV adapter facade, playback capability matrix, playback controller, playback state observation, player clock, and track management behind a single contract-safe entry point.

#### Scenario: Player core runtime is constructed
- **WHEN** the Phase 1 player core runtime is created for tests or early app-shell wiring
- **THEN** it exposes Step 5-8 player-core surfaces without requiring Flutter widgets, native MPV bindings, provider systems, storage internals, streaming engines, or network clients

### Requirement: Player core bootstrap SHALL depend on Phase 0 foundation readiness
The player core bootstrap SHALL be constructible with a Phase 0 foundation runtime or bootstrap dependency and MUST NOT recreate storage, ProviderGateway, cache invalidation, or layer-boundary ownership inside the player-core runtime.

#### Scenario: Foundation dependency is supplied
- **WHEN** player core bootstrap receives a Phase 0 foundation runtime dependency
- **THEN** it uses that dependency only as a foundation readiness boundary and keeps playback lifecycle ownership inside the player-core runtime composition

### Requirement: Player core runtime SHALL provide deterministic lifecycle cleanup
The player core runtime SHALL expose deterministic disposal semantics for its adapter, controller, track, clock, and observation resources.

#### Scenario: Player core runtime is disposed
- **WHEN** the player core runtime is disposed
- **THEN** later playback commands, track operations, and state observation access are rejected with normalized lifecycle failures or state errors rather than leaking native or adapter-specific exceptions

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

