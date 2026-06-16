## ADDED Requirements

### Requirement: Concrete MPV composition factory SHALL expose verified playback runtime inputs
The MPV adapter boundary SHALL provide a Playback-owned composition factory
that returns only the concrete `MpvAdapterBinding` and the verified
`PlaybackCapabilityMatrix` required by player-core runtime wiring.

#### Scenario: App composition root requests local file playback
- **WHEN** the app composition root creates the media_kit/libmpv local-file
  composition with an optional `libmpvPath`
- **THEN** it receives a neutral composition descriptor containing the concrete
  binding and local-file capability matrix without requiring UI code to import
  media_kit/libmpv packages directly

#### Scenario: Unsupported playback source is requested
- **WHEN** the composition descriptor is passed into player-core runtime wiring
  and the UI requests HTTP or HLS playback before those capabilities are
  verified
- **THEN** runtime capability gating rejects the source with a normalized
  unsupported playback failure instead of delegating to the concrete binding
