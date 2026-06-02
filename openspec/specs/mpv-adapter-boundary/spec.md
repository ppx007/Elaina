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

