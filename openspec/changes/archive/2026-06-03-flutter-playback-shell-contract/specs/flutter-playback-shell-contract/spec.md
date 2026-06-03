## ADDED Requirements

### Requirement: Flutter playback shell SHALL consume archived playback contracts
The Flutter playback shell SHALL render from playback page surface descriptors, playback page intents, and playback state snapshots rather than concrete playback adapters, native player bindings, provider systems, streaming systems, gateway, storage, or network layers.

#### Scenario: Shell renders playback contract state
- **WHEN** the shell receives a playback state snapshot and surface descriptor
- **THEN** it renders status, timeline, buffering, controls, and panel entry points from those contracts without importing MPV, VLC, libmpv, media-kit, provider internals, streaming internals, gateway, storage, network, or native bindings

### Requirement: Flutter playback shell SHALL dispatch plain playback intents
The Flutter playback shell SHALL translate user interaction into `PlaybackPageIntent` values and MUST NOT call `PlayerAdapter`, MPV bindings, provider clients, streaming systems, gateway, storage, or network code directly.

#### Scenario: User activates a visible control
- **WHEN** a user activates a visible playback control in the shell
- **THEN** the shell dispatches the corresponding playback page intent through a mock driver or existing UI contract boundary

### Requirement: Flutter playback shell SHALL be mock-driven
The first Flutter playback shell SHALL use deterministic mock state and mock intent handling rather than real playback, native video surfaces, provider metadata, online source parsing, or storage-backed state.

#### Scenario: Shell is tested without native playback
- **WHEN** the shell test renders the playback page
- **THEN** it can validate visible state and intent effects without requiring MPV, VLC, libmpv, media-kit, platform channels, provider systems, streaming systems, storage, gateway, or network access

### Requirement: Flutter playback shell SHALL remain minimal
The Flutter playback shell SHALL be limited to the minimum widget, mock driver, dependency, and validation structure needed to exercise archived playback contracts.

#### Scenario: Shell scope is checked
- **WHEN** the shell implementation is reviewed
- **THEN** it does not include production routing, app-wide navigation, theming system, animations, visual polish, persistence, production state-management packages, or later-phase playback features

### Requirement: Flutter playback shell MUST preserve layer isolation
The Flutter playback shell MUST live in the UI layer and MUST NOT cause Domain, Playback, Provider, Gateway, Storage, Streaming, or Network layers to import Flutter or UI shell types.

#### Scenario: Layer imports are checked
- **WHEN** automation scans Domain, Playback, Provider, Gateway, Storage, Streaming, and Network Dart files
- **THEN** no import points into Flutter UI shell code or Flutter packages are present from those layers
