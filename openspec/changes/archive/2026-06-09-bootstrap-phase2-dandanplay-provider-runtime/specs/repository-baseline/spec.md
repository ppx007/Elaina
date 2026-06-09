## ADDED Requirements

### Requirement: Dandanplay runtime MUST remain optional enrichment
The repository baseline SHALL preserve the architecture rule that Dandanplay runtime behavior is optional danmaku-source enrichment and MUST NOT become a prerequisite for core playback, subtitle runtime, local media handoff, Bangumi metadata/progress, RSS, BT, online-rule, UI, native player, or diagnostics flows.

#### Scenario: Dandanplay runtime is unavailable
- **WHEN** Dandanplay match, search, comment retrieval, or comment posting is unavailable
- **THEN** validation still proves core playback and non-Dandanplay runtime slices can operate without Dandanplay dependencies
