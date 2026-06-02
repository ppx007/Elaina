## ADDED Requirements

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
