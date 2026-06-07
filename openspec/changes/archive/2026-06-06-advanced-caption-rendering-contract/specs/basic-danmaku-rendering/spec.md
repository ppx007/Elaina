## ADDED Requirements

### Requirement: Basic danmaku rendering SHALL remain independent of Matrix4 effects
The system SHALL keep Matrix4 danmaku transforms in advanced caption rendering contracts while preserving basic player-clock timestamps, scrolling/top/bottom modes, filtering, and density controls.

#### Scenario: Matrix4 danmaku is enabled
- **WHEN** advanced caption rendering prepares Matrix4 danmaku effects
- **THEN** basic danmaku comments, filters, density policies, and player-clock eligibility remain unchanged
