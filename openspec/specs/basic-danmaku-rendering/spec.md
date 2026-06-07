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

