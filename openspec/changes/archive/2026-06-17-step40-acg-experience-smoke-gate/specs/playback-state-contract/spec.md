## ADDED Requirements

### Requirement: Playback metadata projections SHALL support ACG smoke gate output
Playback metadata projections produced by the ACG smoke gate SHALL remain
framework-neutral `PlaybackSubtitleStateSnapshot`,
`PlaybackDanmakuStateSnapshot`, and `PlaybackStateSnapshot` values.

#### Scenario: ACG smoke gate prepares playback metadata
- **WHEN** provider subtitle and Dandanplay comment enrichment succeeds
- **THEN** the resulting playback metadata snapshot can be applied to playback
  state without requiring UI widgets, provider clients, native player handles,
  MPV, VLC, libmpv, or media-kit types
