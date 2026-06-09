## ADDED Requirements

### Requirement: Basic danmaku renderer SHALL expose deterministic runtime frames
The basic danmaku renderer SHALL provide a deterministic runtime implementation that turns player-clock snapshots, comments, filters, and density policy into immutable render frames.

#### Scenario: Deterministic frame is requested repeatedly
- **WHEN** the same comments, filter, density policy, and player-clock snapshot are supplied repeatedly
- **THEN** the renderer returns equivalent lane contents and ordering each time

### Requirement: Basic danmaku comments SHALL remain independent from advanced effects
Basic danmaku runtime code SHALL NOT require Matrix4 transforms, advanced caption profiles, PGS rendering, ASS enhancement, masking, concrete renderer geometry, native player handles, or Flutter painting primitives.

#### Scenario: Advanced caption rendering is unavailable
- **WHEN** basic danmaku frames are resolved
- **THEN** scrolling, top, bottom, filtering, and density behavior remain available without advanced caption feature state

### Requirement: Basic danmaku rendering SHALL support provider comment normalization
Basic danmaku rendering SHALL support normalized comment input produced from provider comment contracts while keeping provider retrieval and post-comment behavior outside Playback-layer rendering.

#### Scenario: Provider comments are loaded before rendering
- **WHEN** Dandanplay comment records are normalized into `DanmakuComment` values
- **THEN** the renderer consumes only Playback-layer comment values and does not import ProviderGateway or Dandanplay runtime implementations
