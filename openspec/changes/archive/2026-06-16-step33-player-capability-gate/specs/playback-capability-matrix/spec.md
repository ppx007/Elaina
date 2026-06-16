## ADDED Requirements

### Requirement: Concrete local-file capability gate SHALL expose only verified actions
The concrete local-file playback capability gate SHALL declare local file
playback, play/pause, seek, and stop as supported while keeping unverified
HTTP, HLS, progress reporting, track management, advanced playback, caption
enhancement, danmaku rendering, and fallback capabilities unsupported.

#### Scenario: Media-kit local-file composition is used
- **WHEN** the app composition root creates the media_kit/libmpv local-file
  player runtime composition
- **THEN** its capability matrix exposes only the verified local-file transport
  actions as executable capabilities

#### Scenario: Future UI resolves playback controls
- **WHEN** UI-owned playback code resolves controls from the active capability
  matrix or page surface descriptor
- **THEN** it shows play/pause, seek, and stop for the local-file composition
  but does not show unverified HTTP/HLS, track, advanced playback, danmaku,
  subtitle enhancement, or fallback controls
