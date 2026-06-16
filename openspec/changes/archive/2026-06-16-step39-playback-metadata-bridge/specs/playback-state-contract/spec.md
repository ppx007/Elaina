## ADDED Requirements

### Requirement: Playback state SHALL support metadata bridge projections
Playback state contracts SHALL be able to carry subtitle and danmaku overlay
snapshots produced by a Domain playback metadata bridge without requiring UI
widgets, provider clients, ProviderGateway access, network transports, storage
implementations, native-player handles, MPV, VLC, libmpv, or media-kit types.

#### Scenario: Metadata bridge resolves overlays
- **WHEN** a playback metadata bridge resolves subtitle and danmaku state for a
  player-clock snapshot
- **THEN** the result is represented as framework-neutral
  `PlaybackSubtitleStateSnapshot` and `PlaybackDanmakuStateSnapshot` values
  that existing playback-state and page-surface contracts can consume
