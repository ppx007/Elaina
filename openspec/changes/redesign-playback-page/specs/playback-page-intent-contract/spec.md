## MODIFIED Requirements

### Requirement: Unsupported controls MUST NOT dispatch executable intents
The playback page intent contract MUST check the active playback page surface
descriptor before dispatching executable transport, seek, panel, or
track-selection intents.

#### Scenario: Track switching is unsupported
- **WHEN** audio or subtitle track switching is not exposed by the active
  surface descriptor
- **THEN** a track-selection intent returns an unsupported result without
  calling the Domain track-switching command

## ADDED Requirements

### Requirement: Playback page driver SHALL own UI interaction state
The playback page driver SHALL own UI interaction state such as the currently
loaded track panel snapshot and last intent result, while executable actions
continue to pass through `PlaybackPageIntent`.

#### Scenario: Playback source changes
- **WHEN** the controller publishes a playback state for a different source URI
- **THEN** the driver clears stale discovered track choices before the user
  opens the track panel again
