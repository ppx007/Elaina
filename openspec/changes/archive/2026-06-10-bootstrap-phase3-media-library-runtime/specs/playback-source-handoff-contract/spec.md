## ADDED Requirements

### Requirement: Media-library playback actions SHALL use playback source handoff
Media-library runtime playback actions SHALL pass selected `LocalMediaIdentity` or `MediaScanCandidate` values to `PlaybackSourceHandoffContract` rather than constructing playback sources directly.

#### Scenario: Runtime plays catalog item
- **WHEN** a user or test selects a catalog item for playback through the media-library runtime
- **THEN** the runtime calls `PlaybackSourceHandoffContract.prepare` with an existing local media handoff input and returns a normalized action outcome based on the handoff result

### Requirement: Media-library handoff failures SHALL remain normalized
Media-library runtime playback actions SHALL map missing source data, unsupported URI schemes, unsupported source values, and other handoff failures into explicit runtime outcomes.

#### Scenario: Runtime selects unsupported media URI
- **WHEN** a catalog item or scan candidate cannot be prepared by the handoff contract
- **THEN** the media-library runtime reports an unsupported or unavailable outcome without throwing native-player, UI, provider, storage, network, streaming, MPV, VLC, or platform exceptions

### Requirement: Media-library playback handoff MUST NOT bypass layer boundaries
Media-library runtime playback handoff MUST NOT import concrete player adapters, MPV/VLC bindings, media-kit/libmpv, streaming engines, ProviderGateway internals, storage implementations, network clients, or Flutter UI widgets.

#### Scenario: Runtime handoff boundary is checked
- **WHEN** validation scans media-library runtime and playback handoff usage
- **THEN** only Domain media values and playback source handoff contracts are required for local playback preparation
