## ADDED Requirements

### Requirement: Advanced subtitle intent SHALL be mappable to concrete MPV plans
Advanced caption rendering SHALL remain declarative while allowing a
Playback-owned concrete MPV bridge to translate ordered dual subtitles, ASS
enhancement, and PGS subtitle intent into MPV command plans at the adapter
boundary.

#### Scenario: Advanced subtitle request crosses into Playback binding
- **WHEN** an advanced subtitle request reaches the concrete MPV bridge
- **THEN** subtitle source identity and ordered role are mapped by
  Playback-owned code into MPV command data without changing UI-facing profile
  contracts, basic subtitle parser contracts, or deterministic runtime storage

#### Scenario: Matrix4 danmaku is requested
- **WHEN** Matrix4 danmaku rendering reaches the Step 57 concrete subtitle
  bridge
- **THEN** the bridge returns typed unsupported behavior rather than pretending
  to implement a Flutter/GPU danmaku renderer
