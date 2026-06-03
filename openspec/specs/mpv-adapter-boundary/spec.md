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

