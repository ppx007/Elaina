## ADDED Requirements

### Requirement: Playback capabilities SHALL be adapter and platform scoped
The system SHALL define a capability matrix that combines active adapter capabilities with platform capabilities before UI decisions are made.

#### Scenario: Active adapter changes
- **WHEN** the active player adapter or platform target changes
- **THEN** the capability matrix is recalculated before controls or panels are shown

### Requirement: UI SHALL render playback controls from capabilities
The playback UI SHALL show, hide, or disable controls and secondary panel entry points based on the capability matrix.

#### Scenario: Capability is unavailable
- **WHEN** a capability such as track switching or HLS playback is unavailable
- **THEN** the UI does not present it as an executable action

### Requirement: Capability Matrix SHALL support future adapter expansion
The system SHALL allow future VLC, ExoPlayer, AVPlayer, and platform adapters to add capability rows without rewriting playback UI contracts.

#### Scenario: A future fallback adapter is added
- **WHEN** a later change adds another player adapter
- **THEN** the adapter declares capabilities through the matrix instead of adding adapter-specific UI branches
