# basic-danmaku-rendering Specification

## Purpose
TBD - created by archiving change bootstrap-acg-data-experience. Update Purpose after archive.
## Requirements
### Requirement: Danmaku comments SHALL use player-clock timestamps
The system SHALL represent danmaku comments with timestamps aligned to the player clock.

#### Scenario: Danmaku comment is rendered
- **WHEN** playback reaches a comment timestamp
- **THEN** the comment is eligible for rendering based on player-clock position rather than wall-clock time

### Requirement: Basic renderer SHALL support scrolling, top, and bottom modes
The system SHALL define basic danmaku rendering modes for scrolling, top, and bottom comments.

#### Scenario: Comment mode is selected
- **WHEN** a danmaku comment declares scrolling, top, or bottom mode
- **THEN** the renderer contract maps it to the corresponding basic render lane behavior

### Requirement: Filtering and density controls SHALL be part of the basic renderer
The system SHALL define filtering and density controls for basic danmaku rendering while excluding advanced matrix effects and diagnostics integration.

#### Scenario: Density limit is applied
- **WHEN** too many comments are eligible for the current player-clock window
- **THEN** the renderer contract applies density rules before exposing comments for display

### Requirement: Basic danmaku rendering SHALL remain independent of Matrix4 effects
The system SHALL keep Matrix4 danmaku transforms in advanced caption rendering contracts while preserving basic player-clock timestamps, scrolling/top/bottom modes, filtering, and density controls.

#### Scenario: Matrix4 danmaku is enabled
- **WHEN** advanced caption rendering prepares Matrix4 danmaku effects
- **THEN** basic danmaku comments, filters, density policies, and player-clock eligibility remain unchanged

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

