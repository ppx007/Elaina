## ADDED Requirements

### Requirement: Playback page SHALL stay capability-driven
The playback page SHALL be a thin UI surface that renders video surface state, basic controls, progress state, and secondary panel entry points from Domain/Playback contracts and the capability matrix.

#### Scenario: Playback page initializes
- **WHEN** the playback page opens for a supported source
- **THEN** it renders only controls and entry points allowed by the current capability matrix

### Requirement: Playback page MUST NOT include later-phase integrations
The playback page foundation MUST NOT require provider metadata, danmaku, advanced subtitle rendering, BT streaming, video enhancement, online source parsing, or diagnostics center integration.

#### Scenario: Local file playback is available
- **WHEN** a local file can be played through the active adapter
- **THEN** playback can proceed without Bangumi, Dandanplay, RSS, BT, Anime4K, rule-source, or diagnostics dependencies

### Requirement: Advanced actions SHALL be secondary panel entry points only
The playback page SHALL reserve secondary panel entry points for later advanced actions without implementing those actions in this change.

#### Scenario: Advanced feature is not implemented yet
- **WHEN** a later-phase feature such as danmaku or enhancement is not available
- **THEN** the playback page does not expose it as an active control
