## ADDED Requirements

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
