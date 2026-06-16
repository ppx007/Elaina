# mpv-adapter-boundary Specification

## Purpose
TBD - created by archiving change bootstrap-player-core. Update Purpose after archive.
## Requirements
### Requirement: MPV adapter SHALL be replaceable behind PlayerAdapter
The system SHALL define MPV playback through a replaceable `PlayerAdapter` facade rather than exposing concrete MPV or libmpv bindings to UI code.

#### Scenario: UI starts playback
- **WHEN** the playback page requests playback
- **THEN** it calls Domain or Playback abstractions that resolve an active `PlayerAdapter` instead of importing MPV, libmpv, media-kit, or native player bindings directly

### Requirement: PlayerAdapter SHALL support Phase 1 source types
The system SHALL define player source contracts for local files, HTTP streams, and HLS streams.

#### Scenario: A playback source is opened
- **WHEN** the active adapter receives a local file, HTTP, or HLS source
- **THEN** it reports whether that source type is supported before playback UI exposes unavailable actions

### Requirement: MPV facade MUST NOT claim support without a binding
The MPV adapter facade MUST report local file, HTTP, and HLS playback as unsupported unless a concrete native binding is available behind the `PlayerAdapter` contract.

#### Scenario: MPV binding is unavailable
- **WHEN** the runtime has no concrete MPV binding available
- **THEN** the MPV adapter facade reports the affected playback capabilities as unsupported and the capability matrix prevents executable playback controls for those source types

### Requirement: Adapter lifecycle failures SHALL be normalized
The system SHALL define normalized lifecycle and failure semantics for load, play, pause, seek, stop, and dispose operations.

#### Scenario: Adapter load fails
- **WHEN** a player adapter cannot load a requested source
- **THEN** the failure is returned through a normalized playback failure contract rather than a concrete engine exception leaking across layers

### Requirement: Player adapter SHALL gate source loading by declared capabilities
The active `PlayerAdapter` SHALL return a normalized playback failure when asked to load a source category that is not supported by its current capability matrix.

#### Scenario: HLS source is unsupported
- **WHEN** the active adapter receives an `HlsPlaybackSource` while `hlsPlayback` is unsupported
- **THEN** the load operation returns a `PlaybackCommandResult.failure` with a normalized unsupported or adapter-unavailable failure instead of delegating to a concrete engine blindly

### Requirement: Bound MPV facade SHALL delegate only after binding availability is established
The MPV facade SHALL continue to report all executable playback capabilities as unsupported without a binding, and SHALL delegate load, transport, lifecycle, and track operations only when constructed with a concrete binding.

#### Scenario: Unsupported MPV facade receives playback command
- **WHEN** an unsupported MPV facade receives load, play, pause, seek, stop, dispose, track discovery, or track switching commands
- **THEN** each command returns an explicit normalized unsupported result without throwing a concrete MPV or native binding exception

#### Scenario: Bound MPV facade receives playback command
- **WHEN** a bound MPV facade receives load, play, pause, seek, stop, dispose, track discovery, or track switching commands
- **THEN** the facade delegates through the `MpvAdapterBinding` interface without exposing MPV/libmpv/media-kit types outside the Playback layer

### Requirement: Player adapters SHALL receive normalized playback sources after handoff
Player adapters SHALL receive only normalized `PlaybackSource` values after Domain media selection has been prepared by the playback source handoff contract.

#### Scenario: Adapter receives local media selection
- **WHEN** a local media selection is prepared for playback
- **THEN** the active player adapter receives a local file playback source rather than media library identity, scan candidate, provider metadata, UI selection state, storage records, or concrete platform file handles

### Requirement: Primary adapter failures SHALL remain normalized for fallback strategy
The system SHALL expose fallback-compatible primary adapter failures through normalized playback failure contracts that fallback strategy can consume without importing MPV, libmpv, VLC, native player, or UI dependencies.

#### Scenario: Primary adapter load failure is fallback-compatible
- **WHEN** the primary adapter cannot load a source for a normalized fallback-compatible reason
- **THEN** fallback strategy receives normalized failure data and the playback source rather than concrete MPV, VLC, native exception, or platform player details

### Requirement: MPV facade SHALL participate in player core runtime without binding leakage
The MPV adapter facade SHALL be usable by the Phase 1 player core runtime through `PlayerAdapter` and `MpvAdapterBinding` contracts without exposing MPV, libmpv, media-kit, platform channel, or native handle types outside the Playback layer.

#### Scenario: Runtime uses unsupported facade
- **WHEN** player core runtime is created without a native MPV binding
- **THEN** MPV facade commands return normalized unsupported results and no concrete MPV/libmpv/media-kit type crosses into Domain, UI, Foundation, Provider, Storage, Streaming, or Network layers

### Requirement: Bound MPV facade SHALL report runtime capabilities before commands execute
The MPV facade SHALL expose its source, transport, track, progress, and lifecycle capabilities to player core runtime before playback controller commands are treated as executable.

#### Scenario: Runtime receives playback command
- **WHEN** player core runtime handles a command through a bound MPV facade
- **THEN** the command is gated by the facade capability declaration before delegation to the binding

### Requirement: Concrete MPV binding SHALL drive local file playback without UI ownership
The MPV adapter boundary SHALL support a concrete media_kit/libmpv-backed
`MpvAdapterBinding` that maps local file load, play, pause, seek, stop, and
dispose operations into normalized playback command results without requiring
Flutter page, route, file picker, or video-surface implementation.

#### Scenario: Concrete binding handles a local file
- **WHEN** the concrete binding receives a `LocalFilePlaybackSource`
- **THEN** it opens the source through the concrete player backend and returns a
  normalized `PlaybackCommandResult` without exposing media_kit/libmpv types to
  Domain, UI, Provider, Storage, Streaming, or Network layers

#### Scenario: Concrete binding receives an unsupported source
- **WHEN** HTTP or HLS support is not declared by the concrete binding
- **THEN** the runtime rejects that source through capability gating before
  treating it as executable playback

### Requirement: Concrete player dependencies SHALL remain Playback-owned
Concrete media_kit/libmpv imports SHALL be restricted to approved Playback
binding implementation and test surfaces. Domain, UI, Provider, Storage,
Streaming, and Network layers MUST NOT import concrete player packages.

#### Scenario: Boundary checker scans concrete player imports
- **WHEN** player-core validation scans source files
- **THEN** concrete player package imports are accepted only in approved
  Playback binding files and rejected elsewhere

### Requirement: Concrete MPV binding SHALL prefer bundled libmpv for production releases
The concrete MPV binding SHALL support an explicitly supplied or bundled
`libmpv-2.dll` path so Windows release artifacts can run without requiring the
customer to install MPV or edit global `PATH`.

#### Scenario: Bundled DLL exists beside the executable
- **WHEN** the concrete backend is created on Windows and `libmpv-2.dll` exists
  beside the running executable
- **THEN** the backend passes that DLL path to `MediaKit.ensureInitialized`
  before creating the player

#### Scenario: Explicit DLL path is supplied by packaging smoke
- **WHEN** a smoke tool or composition root supplies an explicit libmpv DLL path
- **THEN** the backend uses that path instead of relying on ambient machine
  state

#### Scenario: Bundled DLL is unavailable
- **WHEN** no explicit or bundled DLL path is available
- **THEN** player operations continue to return normalized playback failures
  rather than exposing media_kit native initialization exceptions

