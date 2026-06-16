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

### Requirement: Player core bootstrap SHALL accept neutral runtime composition descriptors
The player core bootstrap SHALL accept a neutral composition descriptor that
pairs a player binding with its verified capability matrix, so external app
composition roots can wire concrete playback without Domain runtime files
importing concrete media_kit/libmpv implementation code.

#### Scenario: Composition descriptor is supplied
- **WHEN** the app composition root supplies a player runtime composition
  descriptor
- **THEN** `PlayerCoreBootstrap` constructs a bound `PlayerCoreRuntime` using
  the descriptor binding and capability matrix while preserving the existing
  unsupported and deterministic bootstrap paths

#### Scenario: Concrete player backend is unavailable
- **WHEN** the composition descriptor's concrete binding fails to initialize or
  execute a command
- **THEN** player-core runtime returns the binding's normalized playback failure
  instead of leaking concrete backend exceptions

### Requirement: UI integration SHALL observe lifecycle and dispose runtime through Domain contracts
UI integration SHALL observe playback lifecycle state and dispose player-core
runtime objects through Domain-facing contracts, without importing concrete
media_kit/libmpv backend objects or relying on Flutter widget disposal as the
only runtime cleanup mechanism.

#### Scenario: Playback is opened from a prepared source
- **WHEN** the app integration layer opens a prepared playback source through
  `PlaybackControllerContract`
- **THEN** lifecycle state transitions are observable through
  `PlaybackStateObserver` and `currentState` without requiring UI code to
  inspect concrete backend state

#### Scenario: Player runtime is disposed
- **WHEN** the app integration owner disposes `PlayerCoreBootstrap` or
  `PlayerCoreRuntime`
- **THEN** later commands return normalized disposed failures or state errors
  through Domain contracts rather than leaking concrete backend exceptions
  into UI code

### Requirement: UI integration SHALL present normalized playback errors
UI integration SHALL treat playback command failures, source handoff failures,
and disposed-runtime outcomes as normalized contract results that can be
displayed or logged without parsing concrete backend exception text.

#### Scenario: Unsupported source is opened
- **WHEN** an unsupported source reaches the playback controller
- **THEN** the controller returns a normalized unsupported playback failure and
  publishes failed lifecycle state instead of delegating blindly to the
  concrete player backend

### Requirement: Player core smoke gate SHALL validate packaged release staging
The player core smoke gate SHALL validate that a Windows release directory can
stage `libmpv-2.dll` beside an application executable and produce a zip
containing both files, without requiring UI implementation in the core change.

#### Scenario: Release staging smoke runs
- **WHEN** the smoke gate has access to a libmpv DLL path or directory
- **THEN** it creates a temporary release directory, invokes the Windows
  packaging script, and verifies the generated zip contains a root executable
  and root `libmpv-2.dll`

#### Scenario: External UI runner is added later
- **WHEN** the external UI track adds the real Windows runner and executable
- **THEN** the same packaging script and smoke checklist apply to the real
  release directory without requiring customers to install MPV or edit global
  `PATH`

