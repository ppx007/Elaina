## ADDED Requirements

### Requirement: Bangumi runtime MUST remain optional enrichment
The repository baseline SHALL preserve the architecture rule that Bangumi runtime behavior is optional metadata/progress enrichment and MUST NOT become a prerequisite for core playback, subtitle runtime, local media handoff, Dandanplay, RSS, BT, online-rule, or diagnostics flows.

#### Scenario: Bangumi runtime is unavailable
- **WHEN** Bangumi subject lookup, auth session, or progress sync is unavailable
- **THEN** validation still proves core playback and non-Bangumi runtime slices can operate without Bangumi dependencies
