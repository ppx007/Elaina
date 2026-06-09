## ADDED Requirements

### Requirement: Basic danmaku runtime MUST remain a playback overlay capability
The repository baseline SHALL preserve the architecture rule that basic danmaku runtime behavior is a player-clock-driven playback overlay capability and MUST NOT become a prerequisite for Dandanplay provider availability, Bangumi metadata/progress, subtitle runtime, RSS, BT, online-rule, network policy, storage migration, Flutter UI, Matrix4 advanced captions, diagnostics, or native player implementations.

#### Scenario: Basic danmaku runtime is unavailable
- **WHEN** basic danmaku comments, filters, density policy, or frame resolution are unavailable
- **THEN** validation still proves core playback, subtitle runtime, Dandanplay provider runtime, and non-danmaku runtime slices can operate without basic danmaku dependencies
