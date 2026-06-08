# track-management Specification

## Purpose
TBD - created by archiving change bootstrap-player-core. Update Purpose after archive.
## Requirements
### Requirement: Audio and subtitle tracks SHALL use normalized descriptors
The system SHALL represent audio and subtitle tracks with normalized descriptors independent of the concrete player adapter.

#### Scenario: Adapter reports tracks
- **WHEN** a player adapter reports available tracks
- **THEN** Domain and UI code receive normalized audio and subtitle track descriptors rather than engine-specific track objects

### Requirement: Track switching SHALL route through Playback contracts
The system SHALL switch audio and subtitle tracks through Playback-layer contracts instead of UI calling concrete adapter APIs directly.

#### Scenario: User changes subtitle track
- **WHEN** a user chooses a subtitle track
- **THEN** the request is sent through the Playback contract and then delegated to the active adapter

### Requirement: Unsupported track operations SHALL be explicit
The system SHALL report unsupported track discovery or switching as explicit capability or failure states.

#### Scenario: Adapter cannot switch subtitle tracks
- **WHEN** the active adapter cannot switch subtitle tracks
- **THEN** the capability matrix marks subtitle switching unavailable and UI does not expose the action

### Requirement: Track runtime checks SHALL use normalized descriptors
The runtime slice SHALL verify audio and subtitle track discovery through normalized track descriptors rather than concrete engine track objects.

#### Scenario: Adapter reports audio and subtitle tracks
- **WHEN** a bound adapter reports available audio and subtitle tracks
- **THEN** Domain and Playback runtime checks receive normalized descriptors with stable track identifiers, labels, and media track kinds

### Requirement: Track switching runtime checks SHALL route through Playback contracts
Track switching verification SHALL invoke Playback-layer contracts and SHALL return normalized success or unsupported results.

#### Scenario: Supported track is selected
- **WHEN** a caller switches to a track identifier known to the active adapter
- **THEN** the switch operation returns a normalized successful `TrackSwitchResult`

#### Scenario: Track switching is unsupported
- **WHEN** a caller requests track switching while the active adapter does not support that operation
- **THEN** the switch operation returns an explicit unsupported `TrackSwitchResult` and the capability matrix prevents UI exposure of the action

### Requirement: Player core runtime SHALL wire track discovery through active adapter
The player core runtime SHALL expose audio and subtitle track discovery through normalized Playback-layer descriptors returned by the active adapter facade.

#### Scenario: Adapter reports runtime tracks
- **WHEN** the active adapter reports audio and subtitle tracks to player core runtime
- **THEN** runtime consumers receive normalized track descriptors without native engine objects or UI-local identifiers

### Requirement: Player core runtime SHALL gate track switching by capability matrix
The player core runtime SHALL route track switching through Playback-layer contracts and SHALL reject track operations that are unsupported by the runtime capability matrix.

#### Scenario: Subtitle switching is unsupported
- **WHEN** a caller requests subtitle track switching while the runtime capability matrix marks subtitle switching unsupported
- **THEN** the switch operation returns a normalized unsupported result without delegating to native playback, UI state, provider metadata, storage, streaming, or network systems

