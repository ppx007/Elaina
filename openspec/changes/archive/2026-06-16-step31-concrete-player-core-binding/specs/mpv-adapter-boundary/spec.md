## ADDED Requirements

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
